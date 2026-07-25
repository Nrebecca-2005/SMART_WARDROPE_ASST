"""Transparent wardrobe matching after the pretrained model classifies an event."""

from __future__ import annotations


class RecommendationEngine:
    _event_terms = {
        'formal': ('formal', 'business', 'shirt', 'trouser', 'blazer', 'dress shoe'),
        'casual': ('casual', 'jean', 't-shirt', 'sneaker', 'polo'),
        'sports': ('sport', 'gym', 'athletic', 'trainer', 'track'),
        'outdoor': ('outdoor', 'jacket', 'boot', 'rain', 'hiking'),
        'general': (),
    }

    # Required categories for complete outfits by event type
    _required_categories = {
        'formal': ['shirt', 'trousers', 'shoes'],
        'casual': ['shirt', 'trousers', 'shoes'],
        'sports': ['sportswear', 'trousers', 'shoes'],
        'outdoor': ['shirt', 'trousers', 'shoes', 'jacket'],
        'general': ['shirt', 'trousers'],
    }

    def recommend(self, *, classification: dict, weather: dict, wardrobe: list[dict], preference: str) -> dict:
        event_type = classification['event_type']
        temperature = float(weather['temperature'])
        condition = weather['condition']
        scored = []
        for item in wardrobe:
            if not item.get('id') or not item.get('name'):
                continue
            text = ' '.join(str(item.get(key, '')).lower() for key in ('name', 'category', 'color', 'style', 'season'))
            score = self._event_score(text, event_type)
            score += self._weather_score(text, temperature, condition)
            score += self._preference_score(text, preference)
            if score > 0:
                scored.append((score, item))

        scored.sort(key=lambda entry: entry[0], reverse=True)
        selected, categories = [], set()
        for _, item in scored:
            category = str(item.get('category', item['name'])).lower()
            if category in categories:
                continue
            selected.append({'id': str(item['id']), 'name': item['name']})
            categories.add(category)
            if len(selected) == 3:
                break

        if not selected:
            return {
                'success': False,
                'message': 'No suitable outfit could be found from your current wardrobe.',
                'event_type': event_type,
                'ai_confidence': classification['confidence'],
            }

        # Detect missing clothing items
        missing_items = self._detect_missing_items(event_type, categories, temperature, condition)
        is_complete = len(missing_items) == 0

        # Generate purchase recommendations for missing items
        purchase_recommendations = self._generate_purchase_recommendations(
            missing_items, event_type, temperature, condition
        )

        # Generate enhanced explanation
        reason = self._enhanced_reason(event_type, temperature, condition, is_complete, missing_items)

        return {
            'success': True,
            'event_type': event_type,
            'ai_confidence': classification['confidence'],
            'weather_summary': f'{temperature:g}°C, {condition}',
            'recommended_items': selected,
            'missing_items': missing_items,
            'is_complete_outfit': is_complete,
            'purchase_recommendations': purchase_recommendations,
            'reason': reason,
        }

    def _event_score(self, text: str, event_type: str) -> int:
        terms = self._event_terms[event_type]
        return 60 if any(term in text for term in terms) else (10 if event_type == 'general' else 0)

    @staticmethod
    def _weather_score(text: str, temperature: float, condition: str) -> int:
        condition = condition.lower()
        if 'rain' in condition and any(term in text for term in ('rain', 'boot', 'jacket')):
            return 25
        if temperature >= 27 and any(term in text for term in ('short', 't-shirt', 'linen', 'light')):
            return 20
        if temperature <= 16 and any(term in text for term in ('jacket', 'coat', 'sweater', 'boot')):
            return 20
        return 5

    @staticmethod
    def _preference_score(text: str, preference: str) -> int:
        if preference == 'formal' and any(term in text for term in ('formal', 'business')):
            return 15
        if preference == 'casual' and 'casual' in text:
            return 15
        if preference == 'comfortable' and any(term in text for term in ('casual', 'sport', 'sneaker')):
            return 15
        return 0

    @staticmethod
    def _reason(event_type: str, temperature: float, condition: str) -> str:
        weather = 'warm' if temperature >= 24 else 'cold' if temperature <= 16 else 'mild'
        return (
            f'The pretrained AI model classified the event as {event_type}. '
            f'The selected items are from your wardrobe and suit the {weather} weather ({temperature:g}°C, {condition}).'
        )

    def _detect_missing_items(self, event_type: str, available_categories: set, temperature: float, condition: str) -> list[dict]:
        """Detect missing clothing categories needed to complete the outfit."""
        required = self._required_categories.get(event_type, [])
        missing = []
        
        for category in required:
            # Check if we have this category (with fuzzy matching)
            has_category = any(
                category in available_cat or available_cat in category
                for available_cat in available_categories
            )
            
            if not has_category:
                # Determine suggested style based on event type
                suggested_style = event_type if event_type != 'general' else 'casual'
                
                # Determine suggested color based on weather
                suggested_color = None
                if temperature <= 16:
                    suggested_color = 'dark'  # Darker colors for cold weather
                elif temperature >= 27:
                    suggested_color = 'light'  # Lighter colors for warm weather
                
                missing.append({
                    'category': category,
                    'reason': f'Required to complete the {event_type} outfit.',
                    'suggested_style': suggested_style,
                    'suggested_color': suggested_color,
                })
        
        # Special case: rain conditions require rain gear
        if 'rain' in condition.lower() and 'jacket' not in available_categories:
            missing.append({
                'category': 'rain jacket',
                'reason': 'Rain protection is needed for the current weather.',
                'suggested_style': 'outdoor',
                'suggested_color': None,
            })
        
        return missing

    def _generate_purchase_recommendations(self, missing_items: list[dict], event_type: str, temperature: float, condition: str) -> list[dict]:
        """Generate purchase recommendations for missing clothing items."""
        recommendations = []
        
        for item in missing_items:
            category = item['category']
            reason = item['reason']
            suggested_style = item.get('suggested_style')
            suggested_color = item.get('suggested_color')
            
            # Determine priority based on importance
            priority = 'medium'
            if category in ['shoes', 'shirt', 'trousers']:
                priority = 'high'  # Essential items
            elif category == 'jacket' and temperature <= 16:
                priority = 'high'  # Cold weather necessity
            
            # Build recommendation description
            description_parts = [category]
            if suggested_style:
                description_parts.append(suggested_style)
            if suggested_color:
                description_parts.append(suggested_color)
            
            recommendation_description = ' '.join(description_parts)
            
            enhanced_reason = (
                f"{reason} "
                f"The event was classified as {event_type} and your wardrobe lacks suitable {category}."
            )
            
            recommendations.append({
                'category': recommendation_description,
                'reason': enhanced_reason,
                'suggested_style': suggested_style,
                'suggested_color': suggested_color,
                'priority': priority,
            })
        
        return recommendations

    def _enhanced_reason(self, event_type: str, temperature: float, condition: str, is_complete: bool, missing_items: list[dict]) -> str:
        """Generate enhanced explanation including missing items if any."""
        weather = 'warm' if temperature >= 24 else 'cold' if temperature <= 16 else 'mild'
        base_reason = (
            f'The pretrained AI model classified the event as {event_type}. '
            f'The selected items are from your wardrobe and suit the {weather} weather ({temperature:g}°C, {condition}).'
        )
        
        if not is_complete and missing_items:
            missing_categories = [item['category'] for item in missing_items]
            missing_text = ', '.join(missing_categories)
            base_reason += f' Your wardrobe is missing {missing_text} to complete the outfit.'
        
        return base_reason
