# Mobile protocol (what the app expects from the backend)

Base URL: `http(s)://<host>:8000`. If `API_KEY` is set in the backend `.env`, send it as `X-API-Key` (REST) or `?token=` (WebSocket).
`sid` is a per-install session id (UUID) so several phones can use one server without sharing state.

| Endpoint | Notes |
|---|---|
| `WS /ws/detect?sid=&token=&depth=0` | Send binary JPEG; one frame in flight. Receive JSON: `frame_id, detections[{box,confidence,class_name,track_id,is_approaching}], hazards[{class_name,direction_key,proximity,is_urgent}], hazard_alert, is_urgent, corridor{x_min,x_max}, inference_time_ms, ...`. Box and corridor values are pixels of the frame you sent. `depth=1` adds a base64 depth map. |
| `GET /health` | No auth. `{status, version, auth_required, yolo_loaded}` |
| `GET /api/describe_scene?sid=` | `{description, success}` for the last frame of that session |
| `GET /api/ask_question?q=&sid=` | `{answer, success}` |
| `POST /api/register_face_multi` | multipart: `name`, `files[]` |
| `GET /api/faces`, `DELETE /api/faces/{name}` | list / delete registered faces |
