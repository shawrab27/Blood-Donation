# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re

with open("api/views_bloodhub.py", "r", encoding="utf-8") as f:
    content = f.read()

target = """def donor_map_view(request):
    \"\"\"
    Returns fuzzed coordinates (~500m) for donors within an area or boundary.
    Strictly excludes non-searchable donors and unverified coordinates.
    \"\"\"
    blood_group = request.query_params.get('blood_group', '').strip()
    component = request.query_params.get('component', 'WHOLE').strip()
    district = request.query_params.get('district', '').strip()

    queryset = DonorProfile.objects.filter(
        is_searchable=True,
        is_available=True,
    ).exclude(
        Q(latitude__isnull=True) & Q(last_lat__isnull=True)
    )

    if blood_group:
        compatible_groups = get_compatible_donor_groups(blood_group, component)
        queryset = queryset.filter(blood_group__in=compatible_groups)

    if district:
        queryset = queryset.filter(district__icontains=district)

    results = queryset[:100]
    serializer = DonorMapSerializer(results, many=True)
    return Response({
        'count': len(results),
        'donors': serializer.data,
    }, status=status.HTTP_200_OK)"""

replacement = """def donor_map_view(request):
    \"\"\"
    Returns fuzzed coordinates (~500m) for donors within an area or boundary.
    Strictly excludes non-searchable donors and unverified coordinates.
    \"\"\"
    blood_group = request.query_params.get('blood_group', '').strip()
    component = request.query_params.get('component', 'WHOLE').strip()
    district = request.query_params.get('district', '').strip()

    lat_str = request.query_params.get('lat', '').strip()
    lng_str = request.query_params.get('lng', '').strip()
    radius_str = request.query_params.get('radius', '15.0').strip() # Default 15km for map view

    queryset = DonorProfile.objects.filter(
        is_searchable=True,
        is_available=True,
    ).exclude(
        Q(latitude__isnull=True) & Q(last_lat__isnull=True)
    )

    if blood_group:
        compatible_groups = get_compatible_donor_groups(blood_group, component)
        queryset = queryset.filter(blood_group__in=compatible_groups)

    if district:
        queryset = queryset.filter(district__icontains=district)

    if lat_str and lng_str:
        try:
            req_lat = float(lat_str)
            req_lng = float(lng_str)
            radius = float(radius_str)
            
            filtered_results = []
            for d in queryset:
                lat = float(d.latitude or d.last_lat)
                lng = float(d.longitude or d.last_lng)
                dist = haversine_distance(req_lat, req_lng, lat, lng)
                if dist <= radius:
                    filtered_results.append(d)
                    
            results = filtered_results[:100]
        except ValueError:
            results = queryset[:100]
    else:
        results = queryset[:100]

    serializer = DonorMapSerializer(results, many=True)
    return Response({
        'count': len(results),
        'donors': serializer.data,
    }, status=status.HTTP_200_OK)"""

if target in content:
    content = content.replace(target, replacement)
    with open("api/views_bloodhub.py", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced successfully")
else:
    print("Target not found!")
