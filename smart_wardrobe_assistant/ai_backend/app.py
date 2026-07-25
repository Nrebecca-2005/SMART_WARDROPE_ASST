"""Local AI backend for Smart Wardrobe Assistant.

Run with: python app.py
The first request downloads the requested pretrained model if it is not cached.
"""

from flask import Flask, jsonify, request
from flask_cors import CORS

from services.background_removal_service import BackgroundRemovalService
from services.event_classifier import EventClassifier, ModelUnavailableError
from services.fashion_ai_service import FashionAIService
from services.recommendation_service import RecommendationEngine
from services.yolo_service import YoloDetectionService


def create_app(
    event_classifier: EventClassifier | None = None,
    recommendation_engine: RecommendationEngine | None = None,
    fashion_service: FashionAIService | None = None,
    background_service: BackgroundRemovalService | None = None,
    yolo_service: YoloDetectionService | None = None,
) -> Flask:
    app = Flask(__name__)
    CORS(app)
    classifier = event_classifier or EventClassifier()
    engine = recommendation_engine or RecommendationEngine()
    fashion = fashion_service or FashionAIService()
    background = background_service or BackgroundRemovalService()
    yolo = yolo_service or YoloDetectionService()

    @app.get('/health')
    def health():
        return jsonify({'success': True, 'service': 'smart-wardrobe-ai'})

    @app.post('/api/classify-event')
    def classify_event():
        payload = request.get_json(silent=True) or {}
        event_text = payload.get('event_text')
        if not isinstance(event_text, str) or not event_text.strip():
            return jsonify({'success': False, 'message': 'event_text is required.'}), 400
        try:
            return jsonify({'success': True, **classifier.classify(event_text)})
        except ModelUnavailableError as error:
            return jsonify({'success': False, 'message': str(error)}), 503

    @app.post('/api/recommend-outfit')
    def recommend_outfit():
        payload = request.get_json(silent=True) or {}
        event = payload.get('event') or {}
        weather = payload.get('weather') or {}
        wardrobe = payload.get('wardrobe')
        if not isinstance(event.get('title'), str) or not event['title'].strip():
            return jsonify({'success': False, 'message': 'event.title is required.'}), 400
        if not isinstance(weather.get('temperature'), (int, float)) or not isinstance(weather.get('condition'), str):
            return jsonify({'success': False, 'message': 'weather.temperature and weather.condition are required.'}), 400
        if not isinstance(wardrobe, list):
            return jsonify({'success': False, 'message': 'wardrobe must be a list.'}), 400
        try:
            classification = classifier.classify(event['title'])
            return jsonify(engine.recommend(
                classification=classification,
                weather=weather,
                wardrobe=wardrobe,
                preference=payload.get('preference', 'balanced'),
            ))
        except ModelUnavailableError as error:
            return jsonify({'success': False, 'message': str(error)}), 503

    def _analyze_clothing():
        image = request.files.get('image')
        if image is None or not image.filename:
            return jsonify({'success': False, 'message': 'An image file is required.'}), 400
        try:
            return jsonify({'success': True, **fashion.analyze(image.stream)})
        except ModelUnavailableError as error:
            return jsonify({'success': False, 'message': str(error)}), 503

    @app.post('/api/analyze-clothing')
    def analyze_clothing():
        return _analyze_clothing()

    @app.post('/api/analyze-clothing-image')
    def analyze_clothing_image():
        return _analyze_clothing()

    @app.post('/api/remove-background')
    def remove_background():
        image = request.files.get('image')
        if image is None or not image.filename:
            return jsonify({'success': False, 'message': 'An image file is required.'}), 400
        try:
            return jsonify({'success': True, **background.remove_background(image.stream)})
        except ModelUnavailableError as error:
            return jsonify({'success': False, 'message': str(error)}), 503

    @app.post('/api/detect-clothing')
    def detect_clothing():
        image = request.files.get('image')
        if image is None or not image.filename:
            return jsonify({'success': False, 'message': 'An image file is required.'}), 400
        try:
            return jsonify({'success': True, **yolo.detect(image.stream)})
        except ModelUnavailableError as error:
            return jsonify({'success': False, 'message': str(error)}), 503

    return app


if __name__ == '__main__':
    create_app().run(host='0.0.0.0', port=8000, debug=True)
