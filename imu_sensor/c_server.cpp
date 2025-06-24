#include <iostream>
#include <string>
#include <cstring>
#include <arpa/inet.h>
#include <unistd.h>
#include "json.hpp"  // https://github.com/nlohmann/json

using json = nlohmann::json;

int main() {
    int sockfd;
    struct sockaddr_in serverAddr, clientAddr;
    socklen_t addrLen = sizeof(clientAddr);
    char buffer[1024];

    // 建立 UDP socket
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("Socket creation failed");
        return 1;
    }

    // 設定 server 位址
    memset(&serverAddr, 0, sizeof(serverAddr));
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_addr.s_addr = INADDR_ANY;
    serverAddr.sin_port = htons(45678);  // Port 要跟手機一致

    // 綁定
    if (bind(sockfd, (const struct sockaddr *)&serverAddr, sizeof(serverAddr)) < 0) {
        perror("Bind failed");
        close(sockfd);
        return 1;
    }

    std::cout << "Listening for UDP data..." << std::endl;

    while (true) {
        int n = recvfrom(sockfd, buffer, sizeof(buffer) - 1, 0,
                         (struct sockaddr *)&clientAddr, &addrLen);
        if (n < 0) {
            perror("recvfrom error");
            continue;
        }

        buffer[n] = '\0';  // 結尾加 NULL

        try {
            json j = json::parse(buffer);
            float yaw = j["yaw"];
            float pitch = j["pitch"];
            float roll = j["roll"];

            std::cout << "Received Yaw: " << yaw
                      << ", Pitch: " << pitch
                      << ", Roll: " << roll << std::endl;

            // ✅ 這邊你就可以直接餵給 Gsplat camera 或其他你的 C++ 系統
        } catch (json::exception& e) {
            std::cerr << "Invalid JSON: " << buffer << "\nError: " << e.what() << std::endl;
        }
    }

    close(sockfd);
    return 0;
}
