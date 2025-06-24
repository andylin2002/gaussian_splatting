import socket
import json

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('0.0.0.0', 12345))

print("Listening for UDP data...")

while True:
    data, addr = sock.recvfrom(1024)
    try:
        msg = json.loads(data.decode('utf-8'))
        yaw = msg['yaw']
        pitch = msg['pitch']
        roll = msg['roll']
        print(f"Received Yaw: {yaw}, Pitch: {pitch}, Roll: {roll}")
    except Exception as e:
        print(f"Invalid data: {data}, Error: {e}")