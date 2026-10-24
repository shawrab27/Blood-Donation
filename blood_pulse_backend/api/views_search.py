from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from django.db.models import Case, When, Value, IntegerField, Q
from .models import Institution, InstitutionAlias, Upazila

from rest_framework.throttling import AnonRateThrottle, UserRateThrottle


class InstitutionAnonThrottle(AnonRateThrottle):
    scope = 'institutions_anon'
    rate = '60/min'


class InstitutionUserThrottle(UserRateThrottle):
    scope = 'institutions_user'
    rate = '120/min'


@api_view(['GET'])
@permission_classes([AllowAny])
@throttle_classes([InstitutionAnonThrottle, InstitutionUserThrottle])
def institution_search(request):
    q = request.GET.get('q', '').strip()
    if len(q) < 2:
        return Response([])

    itype = request.GET.get('type', '').strip()
    district = request.GET.get('district', '').strip()

    # Split query into words: match when ALL words appear in the name (any order, case-insensitive)
    words = [w for w in q.split() if w]
    word_filter = Q()
    for w in words:
        word_filter &= Q(name__icontains=w)

    # Check for alias matches
    alias_eiins = list(
        InstitutionAlias.objects.filter(alias__iexact=q).values_list('eiin', flat=True)
    )

    if alias_eiins:
        base_filter = word_filter | Q(eiin__in=alias_eiins)
    else:
        base_filter = word_filter

    qs = Institution.objects.filter(base_filter).select_related('district')
    if itype:
        qs = qs.filter(institution_type=itype)
    if district:
        if district.isdigit():
            qs = qs.filter(district_id=int(district))
        else:
            qs = qs.filter(district_name__iexact=district)

    # Ranking:
    # 1. Prefix-of-whole-query or alias match gets top priority (Value(2))
    # 2. All-words match gets secondary priority (Value(1))
    when_conditions = [
        When(name__istartswith=q, then=Value(2)),
    ]
    if alias_eiins:
        when_conditions.append(When(eiin__in=alias_eiins, then=Value(2)))

    results = qs.annotate(
        rank=Case(
            *when_conditions,
            default=Value(1),
            output_field=IntegerField()
        )
    ).order_by('-rank', 'name')[:10]

    data = [
        {
            'id': inst.id,
            'name': inst.name,
            'institution_type': inst.institution_type,
            'eiin': inst.eiin,
            'district_name': inst.district_name or (inst.district.name if inst.district else None),
        }
        for inst in results
    ]
    return Response(data)



@api_view(['GET'])
@permission_classes([AllowAny])
def upazila_search(request):
    from api.data.bd_upazilas import BD_DISTRICT_UPAZILAS
    from api.data.bd_locations import DISTRICT_ALIASES

    q = request.GET.get('q', '').strip()
    district_raw = request.GET.get('district') or request.GET.get('district_id') or ''
    district_str = str(district_raw).strip()
    canonical_district = DISTRICT_ALIASES.get(district_str, district_str)

    if not q and not district_str:
        return Response([])

    qs = Upazila.objects.exclude(name__contains='├').exclude(name__contains='│').exclude(name__contains='└')
    if q:
        qs = qs.filter(name__icontains=q)

    if district_str:
        if district_str.isdigit():
            qs = qs.filter(district_id=int(district_str))
        else:
            qs = qs.filter(district__name__iexact=canonical_district)

    if q:
        results = list(qs.annotate(
            starts_with=Case(
                When(name__istartswith=q, then=Value(1)),
                default=Value(0),
                output_field=IntegerField()
            )
        ).order_by('-starts_with', 'name')[:25])
    else:
        results = list(qs.order_by('name')[:50])

    if results:
        data = [
            {
                'id': up.id,
                'name': up.name,
                'district_id': up.district_id
            }
            for up in results
        ]
        return Response(data)

    fallback_upazilas = BD_DISTRICT_UPAZILAS.get(canonical_district, [])
    if not fallback_upazilas and not district_str:
        fallback_upazilas = [u for upz_list in BD_DISTRICT_UPAZILAS.values() for u in upz_list]

    if q:
        q_lower = q.lower()
        filtered = [u for u in fallback_upazilas if q_lower in u.lower()]
        filtered.sort(key=lambda u: (not u.lower().startswith(q_lower), u))
    else:
        filtered = sorted(fallback_upazilas)

    data = [
        {
            'id': None,
            'name': u,
            'district_id': None,
        }
        for u in filtered[:25]
    ]
    return Response(data)
