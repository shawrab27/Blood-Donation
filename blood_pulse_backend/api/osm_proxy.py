import requests
import logging
from django.core.cache import cache
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from api.throttles import OSMProxyThrottle

logger = logging.getLogger(__name__)

class GeocodeView(APIView):
    throttle_classes = [OSMProxyThrottle]

    def get(self, request, *args, **kwargs):
        q = request.query_params.get('q')
        if not q:
            return Response({'error': 'Missing query param q'}, status=status.HTTP_400_BAD_REQUEST)
        
        cache_key = f"geocode_{q.strip().lower()}"
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
    throttle_classes = [OSMProxyThrottle]

    def get(self, request, *args, **kwargs):
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')
        
        if not lat or not lng:
            return Response({'error': 'Missing lat/lng'}, status=status.HTTP_400_BAD_REQUEST)
            
        cache_key = f"rev_geocode_{lat}_{lng}"
        cached = cache.get(cache_key)
        if cached is not None:
            return Response(cached)

        try:
            res = requests.get(
                'https://nominatim.openstreetmap.org/reverse',
                params={'lat': lat, 'lon': lng, 'format': 'json', 'zoom': 14},
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
    throttle_classes = [OSMProxyThrottle]

    def get(self, request, *args, **kwargs):
        from_lat = request.query_params.get('from_lat')
        from_lng = request.query_params.get('from_lng')
        to_lat = request.query_params.get('to_lat')
        to_lng = request.query_params.get('to_lng')
        
        if not all([from_lat, from_lng, to_lat, to_lng]):
            return Response({'error': 'Missing from_lat/lng or to_lat/lng'}, status=status.HTTP_400_BAD_REQUEST)

        cache_key = f"route_{from_lat}_{from_lng}_{to_lat}_{to_lng}"
        cached = cache.get(cache_key)
        if cached is not None:
            return Response(cached)

        try:
            # {lng},{lat};{lng},{lat}
            coords = f"{from_lng},{from_lat};{to_lng},{to_lat}"
            res = requests.get(
                f'https://router.project-osrm.org/route/v1/driving/{coords}',
                params={'overview': 'false'},
                timeout=5
            )
            res.raise_for_status()
            data = res.json()
            
            routes = data.get('routes', [])
            if not routes:
                return Response({'error': 'No route found'}, status=status.HTTP_404_NOT_FOUND)
                
            distance_meters = routes[0].get('distance', 0)
            duration_seconds = routes[0].get('duration', 0)
            
            result = {
                'distance_km': round(distance_meters / 1000.0, 1),
                'duration_min': round(duration_seconds / 60.0, 1)
            }
            
            cache.set(cache_key, result, 3600) # 1h
            return Response(result)
            
        except requests.exceptions.Timeout:
            return Response({'error': 'OSM service timeout'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except Exception as e:
            logger.error(f"Route error: {e}")
            return Response({'error': 'OSM service error'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
