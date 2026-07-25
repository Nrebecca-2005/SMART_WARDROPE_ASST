"""YOLOv8 object detection for the clothing capture flow.

Honest scope note:
    The default weights (``yolov8n.pt``) are trained on the COCO dataset, which
    does NOT contain fine-grained clothing categories (shirt vs. blazer, etc.).
    This service is therefore responsible only for DETECTION / LOCALIZATION:
    it finds objects, returns their real class label, confidence and bounding
    box, and crops the most prominent detection so it can be passed to the
    background-removal and Fashion-CLIP classification steps.

    Detailed clothing CLASSIFICATION (category / style / colour) stays in
    ``fashion_ai_service.py``. Detection and classification are kept separate on
    purpose so no component pretends to do something it was not trained for.
"""

from __future__ import annotations

import base64
import io

from PIL import Image

from services.event_classifier import ModelUnavailableError


class YoloDetectionService:
    model_name = 'yolov8n.pt'
    # COCO does not label clothing directly; "person" is the closest signal for
    # a worn garment. Flat-lay photos may return no detection, which is honest.
    confidence_threshold = 0.25

    def __init__(self) -> None:
        self._model = None

    def _get_model(self):
        if self._model is None:
            try:
                from ultralytics import YOLO

                self._model = YOLO(self.model_name)
            except Exception as error:  # pragma: no cover - machine/network dependent
                raise ModelUnavailableError(
                    'The YOLO detection model could not be loaded. Install '
                    'ultralytics and start the backend once with internet access '
                    'so it can download yolov8n.pt.'
                ) from error
        return self._model

    def detect(self, image_stream) -> dict:
        image = Image.open(image_stream).convert('RGB')
        model = self._get_model()

        results = model.predict(image, conf=self.confidence_threshold, verbose=False)
        objects: list[dict] = []
        if results:
            result = results[0]
            names = result.names
            for box in result.boxes:
                x1, y1, x2, y2 = (float(value) for value in box.xyxy[0].tolist())
                confidence = float(box.conf[0])
                class_id = int(box.cls[0])
                objects.append({
                    'class': str(names.get(class_id, str(class_id))),
                    'confidence': confidence,
                    'bounding_box': {
                        'x': int(round(x1)),
                        'y': int(round(y1)),
                        'width': int(round(x2 - x1)),
                        'height': int(round(y2 - y1)),
                    },
                })

        objects.sort(key=lambda item: item['confidence'], reverse=True)
        primary = objects[0] if objects else None
        detected = primary is not None

        cropped_image_base64 = None
        if detected:
            cropped_image_base64 = self._crop_primary(image, primary['bounding_box'])

        # Explicit fallback contract. YOLO is never a hard requirement: whether or
        # not it finds an object, fashion classification (Fashion-CLIP) still runs.
        response = {
            'yolo_detected': detected,
            # `detection` is the single most-confident object, or null. We never
            # fabricate a detection when YOLO returns zero boxes.
            'detection': primary,
            'fashion_analysis_required': True,
            # Backward-compatible fields for the existing capture flow.
            'objects': objects,
            'primary': primary,
            'object_count': len(objects),
            'cropped_image_base64': cropped_image_base64,
            'model': self.model_name,
            # Made explicit so callers never treat detection as classification.
            'note': (
                'YOLOv8 (COCO) performs detection only; detailed clothing '
                'category, style and colour are produced by Fashion-CLIP.'
            ),
        }
        if not detected:
            # Records that YOLO produced no valid detection and the pipeline
            # continues on the fashion classifier instead.
            response['fallback'] = 'fashion_classifier'
        return response

    @staticmethod
    def _crop_primary(image: Image.Image, box: dict, padding: float = 0.08) -> str:
        width, height = image.size
        pad_x = int(box['width'] * padding)
        pad_y = int(box['height'] * padding)
        left = max(0, box['x'] - pad_x)
        top = max(0, box['y'] - pad_y)
        right = min(width, box['x'] + box['width'] + pad_x)
        bottom = min(height, box['y'] + box['height'] + pad_y)
        if right <= left or bottom <= top:
            return None
        cropped = image.crop((left, top, right, bottom))
        buffer = io.BytesIO()
        cropped.save(buffer, format='PNG')
        return base64.b64encode(buffer.getvalue()).decode('ascii')
