from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from django.db.models import Case, When, Value, IntegerField
from .models import Institution, Upazila

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

    qs = Institution.objects.filter(name__icontains=q).select_related('district')
    if itype:
        qs = qs.filter(institution_type=itype)
    if district:
        if district.isdigit():
            qs = qs.filter(district_id=int(district))
        else:
            qs = qs.filter(district_name__iexact=district)

    results = qs.annotate(
        starts_with=Case(
            When(name__istartswith=q, then=Value(1)),
            default=Value(0),
            output_field=IntegerField()
        )
    ).order_by('-starts_with', 'name')[:20]

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
