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
    q = request.GET.get('q', '').strip()
    if not q:
        return Response([])

    results = Upazila.objects.filter(name__icontains=q).annotate(
        starts_with=Case(
            When(name__istartswith=q, then=Value(1)),
            default=Value(0),
            output_field=IntegerField()
        )
    ).order_by('-starts_with', 'name')[:10]

    data = [
        {
            'id': up.id,
            'name': up.name,
            'district_id': up.district_id
        }
        for up in results
    ]
    return Response(data)
