#pragma once
#include <atomic>
#include <thread>
#include <cstdint>

/* ------------------------------------------------------------------
   接收手機 UDP(JSON) → 儲存最新一筆 YPR。
   呼叫順序：
      1)  auto rcv = std::make_shared<HeadPoseReceiver>();
          rcv->start(12345);           // 建 socket + 開 thread
      2)  auto pose = rcv->latest();   // 隨時撈最新數據
      3)  rcv->stop();                 // 程式結束再呼叫(會 join)
------------------------------------------------------------------ */

struct HeadPose { float yaw = 0.f, pitch = 0.f, roll = 0.f; };

class HeadPoseReceiver {
public:
    bool start(uint16_t port = 12345);   // 開始監聽
    void stop();                         // 停止 & 關閉 thread
    [[nodiscard]] HeadPose latest() const { return _pose.load(); }

private:
    void loop(uint16_t port);            // thread 內部函式

    std::atomic<HeadPose> _pose{};
    int                   _sock = -1;
    std::thread           _th;
    std::atomic<bool>     _running{false};
};