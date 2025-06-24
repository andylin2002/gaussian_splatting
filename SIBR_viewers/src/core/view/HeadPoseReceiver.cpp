#include "HeadPoseReceiver.hpp"
#include <iostream>
#include <cstring>
#include <arpa/inet.h>
#include <unistd.h>
#include "json.hpp"          // nlohmann/single_include/json.hpp

using json = nlohmann::json;

// -------- public -------------------------------------------------
bool HeadPoseReceiver::start(uint16_t port) {
    if(_running.load()) return true;     // 已在跑
    _running = true;
    _th      = std::thread(&HeadPoseReceiver::loop, this, port);
    return true;
}

void HeadPoseReceiver::stop() {
    _running = false;
    if(_th.joinable()) _th.join();
}

// -------- private -----------------------------------------------
void HeadPoseReceiver::loop(uint16_t port) {

    // 1. 建 socket.
    _sock = socket(AF_INET, SOCK_DGRAM, 0);
    if(_sock < 0){
        perror("socket");
        return;
    }

    // 2. bind 0.0.0.0:port.
    sockaddr_in addr; std::memset(&addr, 0, sizeof(addr));
    addr.sin_family      = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port        = htons(port);

    if(bind(_sock, (sockaddr*)&addr, sizeof(addr)) < 0){
        perror("bind");
        close(_sock); _sock = -1; return;
    }
    std::cout << "[HeadPoseReceiver] listening UDP *:" << port << std::endl;

    // 3. 進入 recv loop.
    sockaddr_in cli; socklen_t len = sizeof(cli);
    char buf[1024];

    while(_running.load()){
        int n = recvfrom(_sock, buf, sizeof(buf)-1, MSG_DONTWAIT,
                         (sockaddr*)&cli, &len);
        if(n <= 0) { usleep(1000); continue; }

        buf[n] = '\0';
        try{
            // std::cout << "[RAW] \"" << std::string(buf, n) << "\"\n";
            json j   = json::parse(buf);
            HeadPose p;
            p.yaw   = j.value("yaw",   0.0f);
            p.pitch = j.value("pitch", 0.0f);
            p.roll  = j.value("roll",  0.0f);
            _pose.store(p);
        }catch(const std::exception& e){
            std::cerr << "JSON err: " << e.what() << std::endl;
        }
        
    }

    close(_sock); _sock = -1;
}