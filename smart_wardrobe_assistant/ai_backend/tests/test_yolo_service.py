import io
import unittest

from PIL import Image

from services.yolo_service import YoloDetectionService


class _FakeArray:
    def __init__(self, values):
        self._values = values

    def tolist(self):
        return list(self._values)


class _FakeBox:
    def __init__(self, xyxy, conf, cls):
        self.xyxy = [_FakeArray(xyxy)]
        self.conf = [conf]
        self.cls = [cls]


class _FakeResult:
    names = {0: 'person', 24: 'backpack'}

    def __init__(self, boxes):
        self.boxes = boxes


class _FakeModel:
    def __init__(self, boxes):
        self._boxes = boxes

    def predict(self, image, conf, verbose):  # noqa: D401 - mimics ultralytics API
        return [_FakeResult(self._boxes)]


def _png_stream():
    buffer = io.BytesIO()
    Image.new('RGB', (400, 400), (200, 200, 200)).save(buffer, 'PNG')
    buffer.seek(0)
    return buffer


class YoloDetectionServiceTests(unittest.TestCase):
    def test_detections_are_sorted_and_cropped(self):
        service = YoloDetectionService()
        service._model = _FakeModel([
            _FakeBox([10, 10, 110, 210], 0.42, 24),
            _FakeBox([50, 60, 250, 360], 0.88, 0),
        ])

        result = service.detect(_png_stream())

        self.assertEqual(result['object_count'], 2)
        # Highest confidence detection is primary.
        self.assertEqual(result['primary']['class'], 'person')
        self.assertAlmostEqual(result['primary']['confidence'], 0.88)
        self.assertEqual(
            result['primary']['bounding_box'],
            {'x': 50, 'y': 60, 'width': 200, 'height': 300},
        )
        self.assertIsNotNone(result['cropped_image_base64'])
        # Explicit fallback contract: YOLO succeeded.
        self.assertTrue(result['yolo_detected'])
        self.assertEqual(result['detection'], result['primary'])
        self.assertTrue(result['fashion_analysis_required'])
        # No fallback key when a real detection exists.
        self.assertNotIn('fallback', result)

    def test_no_detection_returns_no_primary_and_no_crop(self):
        service = YoloDetectionService()
        service._model = _FakeModel([])

        result = service.detect(_png_stream())

        self.assertEqual(result['object_count'], 0)
        self.assertIsNone(result['primary'])
        self.assertIsNone(result['cropped_image_base64'])
        # Explicit fallback contract: no fabricated detection, pipeline continues.
        self.assertFalse(result['yolo_detected'])
        self.assertIsNone(result['detection'])
        self.assertTrue(result['fashion_analysis_required'])
        self.assertEqual(result['fallback'], 'fashion_classifier')


if __name__ == '__main__':
    unittest.main()
