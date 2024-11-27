# import cv2
# import numpy as np
# import easyocr
# import torch

# # Initialize EasyOCR Reader with GPU support
# def initialize_reader():
#     if torch.cuda.is_available():
#         print("GPU is available. EasyOCR will use GPU for processing.")
#     else:
#         print("GPU is not available. EasyOCR will use CPU for processing.")
#     reader = easyocr.Reader(['en'], gpu=True)
#     return reader

# def main():
#     # Initialize EasyOCR Reader
#     reader = initialize_reader()

#     # Open video capture
#     cap = cv2.VideoCapture(0)  # 0 for the default camera

#     while True:
#         ret, frame = cap.read()
#         if not ret:
#             break

#         # Flip the frame horizontally to correct the inversion
#         # frame = cv2.flip(frame, 1)

#         # Detect text in the frame
#         results = reader.readtext(frame)

#         # Draw bounding boxes and text on the frame
#         for (bbox, text, prob) in results:
#             (top_left, top_right, bottom_right, bottom_left) = bbox
#             top_left = tuple(map(int, top_left))
#             bottom_right = tuple(map(int, bottom_right))
#             cv2.rectangle(frame, top_left, bottom_right, (0, 255, 0), 2)
#             cv2.putText(frame, text, (top_left[0], top_left[1] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)

#         # Display the frame with bounding boxes
#         cv2.imshow('Text Detection', frame)

#         # Exit on 'q' key press
#         if cv2.waitKey(1) & 0xFF == ord('q'):
#             break

#     # Release the video capture and close windows
#     cap.release()
#     cv2.destroyAllWindows()

# if __name__ == '__main__':
#     main()


# from flask import Flask, request, jsonify
# import torch
# import cv2
# import numpy as np
# from ultralytics import YOLO
# import base64
# import easyocr

# app = Flask(__name__)

# # Load the YOLOv8 model
# model = YOLO("yolov8x.pt")

# # Load the MiDaS model
# midas = torch.hub.load("intel-isl/MiDaS", "MiDaS_small")
# midas_transforms = torch.hub.load("intel-isl/MiDaS", "transforms")
# transform = midas_transforms.small_transform

# if torch.cuda.is_available():
#     print("GPU is available. EasyOCR will use GPU for processing.")
# else:
#     print("GPU is not available. EasyOCR will use CPU for processing.")
#     ocr_reader = easyocr.Reader(['en'], gpu=True)

# if torch.cuda.is_available():
#     print("GPU is available. MiDaS will use GPU for processing.")
# else:
#     print("GPU is not available. MiDaS will use CPU for processing.")

# device = torch.device("cuda") if torch.cuda.is_available() else torch.device("cpu")
# midas.to(device)
# midas.eval()

# def get_horizontal_displacement(x_center, image_width):
#     displacement = (x_center - image_width // 2) / (image_width // 2)
#     return displacement

# # Confidence threshold
# confidence_threshold = 0.5

# @app.route('/process_image', methods=['POST'])
# def process_image():
#     data = request.json
#     image_data = base64.b64decode(data['image'])
#     np_img = np.frombuffer(image_data, np.uint8)
#     frame = cv2.imdecode(np_img, cv2.IMREAD_COLOR)

#     # Detect objects using YOLOv8
#     results = model(frame)

#     # Detect text using EasyOCR
#     ocr_results = ocr_reader.readtext(frame)

#     # Prepare image for MiDaS
#     img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
#     input_batch = transform(img_rgb).to(device)

#     # Generate depth map with MiDaS
#     with torch.no_grad():
#         prediction = midas(input_batch)
#         prediction = torch.nn.functional.interpolate(
#             prediction.unsqueeze(1),
#             size=img_rgb.shape[:2],
#             mode="bicubic",
#             align_corners=False,
#         ).squeeze()
    
#     depth_map = prediction.cpu().numpy()

#     # Invert depth values for correct interpretation
#     depth_map = np.max(depth_map) - depth_map

#     detected_objects = []
#     image_width = frame.shape[1]

#     for result in results:
#         for box in result.boxes:
#             if box.conf.item() >= confidence_threshold:
#                 x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
#                 x_center = (x1 + x2) // 2
#                 horizontal_displacement = get_horizontal_displacement(x_center, image_width)

#                 roi = depth_map[y1:y2, x1:x2]
#                 avg_depth = np.mean(roi)
#                 class_name = model.names[int(box.cls.item())]

#                 detected_objects.append({
#                     "object": class_name,
#                     "depth": float(avg_depth),
#                     "horizontal_displacement": horizontal_displacement
#                 })
    
#     return jsonify({"detected_objects": detected_objects})

# if __name__ == '__main__':
#     app.run(host='0.0.0.0', port=5000)
from flask import Flask, request, jsonify
import torch
import cv2
import numpy as np
from ultralytics import YOLO
import base64
import easyocr

app = Flask(__name__)

# Load the YOLOv8 model
model = YOLO("yolov8x.pt")

# Load the MiDaS model
midas = torch.hub.load("intel-isl/MiDaS", "MiDaS_small")
midas_transforms = torch.hub.load("intel-isl/MiDaS", "transforms")
transform = midas_transforms.small_transform

# Initialize EasyOCR Reader
# if torch.cuda.is_available():
#     print("GPU is available. EasyOCR will use GPU for processing.")
#     ocr_reader = easyocr.Reader(['en'], gpu=True)
# else:
#     print("GPU is not available. EasyOCR will use CPU for processing.")
#     ocr_reader = easyocr.Reader(['en'], gpu=False)

ocr_reader = easyocr.Reader(['en'], gpu=False)
# Check if GPU is available for MiDaS
# if torch.cuda.is_available():
#     print("GPU is available. MiDaS will use GPU for processing.")
# else:
#     print("GPU is not available. EasyOCR will use CPU for processing.")
device =  torch.device("cpu")
midas.to(device)
midas.eval()

def get_horizontal_displacement(x_center, image_width):
    """Calculate horizontal displacement as a fraction of the image width."""
    displacement = (x_center - image_width // 2) / (image_width // 2)
    return displacement

# Confidence threshold for object detection
confidence_threshold = 0.5

@app.route('/process_image', methods=['POST'])
def process_image():
    # Get and decode image from the POST request
    data = request.json
    image_data = base64.b64decode(data['image'])
    np_img = np.frombuffer(image_data, np.uint8)
    frame = cv2.imdecode(np_img, cv2.IMREAD_COLOR)

    # Detect objects using YOLOv8
    results = model(frame)
    # frame1 = cv2.flip(frame, 1)
    # Detect text using EasyOCR
    ocr_results = ocr_reader.readtext(frame)

    # Prepare the image for MiDaS depth estimation
    img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    input_batch = transform(img_rgb).to(device)

    # Generate depth map using MiDaS
    with torch.no_grad():
        prediction = midas(input_batch)
        prediction = torch.nn.functional.interpolate(
            prediction.unsqueeze(1),
            size=img_rgb.shape[:2],
            mode="bicubic",
            align_corners=False,
        ).squeeze()

    depth_map = prediction.cpu().numpy()

    # Invert depth values for correct interpretation
    depth_map = np.max(depth_map) - depth_map

    detected_objects = []
    detected_texts = []
    image_width = frame.shape[1]

    # Process YOLO object detection results
    for result in results:
        for box in result.boxes:
            if box.conf.item() >= confidence_threshold:
                x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
                x_center = (x1 + x2) // 2
                horizontal_displacement = get_horizontal_displacement(x_center, image_width)

                # Region of interest for depth calculation
                roi = depth_map[y1:y2, x1:x2]
                avg_depth = np.mean(roi)
                class_name = model.names[int(box.cls.item())]

                detected_objects.append({
                    "object": class_name,
                    "depth": float(avg_depth),
                    "horizontal_displacement": horizontal_displacement
                })

    # Process OCR results
    for (bbox, text, prob) in ocr_results:
        (top_left, top_right, bottom_right, bottom_left) = bbox
        x1, y1 = map(int, top_left)
        x2, y2 = map(int, bottom_right)
        x_center = (x1 + x2) // 2
        horizontal_displacement = get_horizontal_displacement(x_center, image_width)

        # Region of interest for depth calculation
        roi = depth_map[y1:y2, x1:x2]
        avg_depth = np.mean(roi)

        detected_texts.append({
            "text": text,
            "confidence": float(prob),
            "depth": float(avg_depth),
            "horizontal_displacement": horizontal_displacement,
            "bbox": [x1, y1, x2, y2]
        })
    print(detected_objects,"\n", detected_texts)
    return jsonify({
        "detected_objects": detected_objects,
        "detected_texts": detected_texts
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)