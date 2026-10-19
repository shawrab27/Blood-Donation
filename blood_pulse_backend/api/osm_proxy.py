import requests
import logging
from django.core.cache import cache
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from api.throttles import OSMProxyThrottle

logger = logging.getLogger(__name__)

class GeocodeView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [OSMProxyThrottle]

    def get(self, request, *args, **kwargs):
        q = (request.query_params.get('q') or '').strip()
        if not q:
            return Response({'error': 'Missing query param q'}, status=status.HTTP_400_BAD_REQUEST)
        if len(q) < 2 or len(q) > 100:
            return Response({'error': 'Query length must be between 2 and 100 characters'}, status=status.HTTP_400_BAD_REQUEST)
        
        cache_key = f"geocode_{q.lower()}"
        cached = cache.get(cache_key)
        if cached is not None:
            return Response(cached)

        try:
            res = requests.get(
                'https://nominatim.openstreetmap.org/search',
                params={'q': q, 'format': 'json', 'countrycodes': 'bd', 'limit': 5},
                headers={'User-Agent': 'BloodPulse/1.0'},
                timeout=5
            )
            res.raise_for_status()
            data = res.json()
            
            simplified = []
            for item in data:
                simplified.append({
                    'display_name': item.get('display_name'),
                    'lat': float(item.get('lat')),
                    'lng': float(item.get('lon'))
                })
            
            cache.set(cache_key, simplified, 86400) # 24h
            return Response(simplified)
            
        except requests.exceptions.Timeout:
            return Response({'error': 'OSM service timeout'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except Exception as e:
            logger.error(f"Geocode error: {e}")
            return Response({'error': 'OSM service error'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

class ReverseGeocodeView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [OSMProxyThrottle]

    def get(self, request, *args, **kwargs):
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')
        
        if not lat or not lng:
            return Response({'error': 'Missing lat/lng'}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            lat_f = float(lat)
            lng_f = float(lng)
            if not (-90.0 <= lat_f <= 90.0 and -180.0 <= lng_f <= 180.0):
                return Response({'error': 'Coordinates out of bounds'}, status=status.HTTP_400_BAD_REQUEST)
        except (ValueError, TypeError):
            return Response({'error': 'Invalid lat/lng format'}, status=status.HTTP_400_BAD_REQUEST)

        cache_key = f"rev_geocode_{lat_f}_{lng_f}"
        cached = cache.get(cache_key)
        if cached is not None:
            return Response(cached)

        try:
            res = requests.get(
                'https://nominatim.openstreetmap.org/reverse',
                params={'lat': lat_f, 'lon': lng_f, 'format': 'json', 'zoom': 14},
                headers={'User-Agent': 'BloodPulse/1.0'},
                timeout=5
            )
            res.raise_for_status()
            data = res.json()
            address = data.get('address', {})
            
            simplified = {
                'display_name': data.get('display_name'),
                'district': address.get('state_district') or address.get('county') or address.get('city'),
                'upazila': address.get('suburb') or address.get('town') or address.get('village')
            }
            
            cache.set(cache_key, simplified, 86400) # 24h
            return Response(simplified)
            
        except requests.exceptions.Timeout:
            return Response({'error': 'OSM service timeout'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except Exception as e:
            logger.error(f"Reverse geocode error: {e}")
            return Response({'error': 'OSM service error'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

class RouteView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [OSMProxyThrottle]

    def get(self, request, *args, **kwargs):
        from_lat = request.query_params.get('from_lat')
        from_lng = request.query_params.get('from_lng')
        to_lat = request.query_params.get('to_lat')
        to_lng = request.query_params.get('to_lng')
        overview = request.query_params.get('overview', 'false').lower() == 'true'

        if not all([from_lat, from_lng, to_lat, to_lng]):
            return Response({'error': 'Missing from_lat/lng or to_lat/lng'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            f_lat = float(from_lat)
            f_lng = float(from_lng)
            t_lat = float(to_lat)
            t_lng = float(to_lng)
            if not (-90.0 <= f_lat <= 90.0 and -180.0 <= f_lng <= 180.0 and -90.0 <= t_lat <= 90.0 and -180.0 <= t_lng <= 180.0):
                return Response({'error': 'Coordinates out of bounds'}, status=status.HTTP_400_BAD_REQUEST)
        except (ValueError, TypeError):
            return Response({'error': 'Invalid latitude/longitude format'}, status=status.HTTP_400_BAD_REQUEST)

        from api.services.routing import get_route_or_fallback
        result = get_route_or_fallback(f_lat, f_lng, t_lat, t_lng, overview=overview)
        return Response(result, status=status.HTTP_200_OK)
