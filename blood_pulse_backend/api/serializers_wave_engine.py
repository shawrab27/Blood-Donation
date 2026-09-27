from rest_framework import serializers
from .models import BloodRequest, WaveEscalationLog
from api.conf import WAVE_RADIUS_KM

class WaveDashboardMetricsSerializer(serializers.Serializer):
    active_escalations = serializers.IntegerField()
    wave1_donors_pinged = serializers.IntegerField()
    wave4_broadcasts = serializers.IntegerField()
    avg_match_time_minutes = serializers.FloatField(allow_null=True)

class LiveCasePipelineSerializer(serializers.ModelSerializer):
    escalation_status = serializers.SerializerMethodField()
    hospital_name = serializers.SerializerMethodField()
    pinged_donors_count = serializers.SerializerMethodField()
    accepted_donors_count = serializers.SerializerMethodField()
    search_radius_km = serializers.SerializerMethodField()
    
    class Meta:
        model = BloodRequest
        fields = [
            'id', 
            'blood_group', 
            'urgency', 
            'current_wave', 
            'search_radius_km', 
            'pinged_donors_count',
            'accepted_donors_count',
            'hospital_name',
            'escalation_status',
            'created_at'
        ]

    def get_search_radius_km(self, obj):
        return WAVE_RADIUS_KM.get(obj.current_wave, 150.0)

    def get_pinged_donors_count(self, obj):
        return getattr(obj, 'pinged_donors_count', obj.notifications.count())

    def get_accepted_donors_count(self, obj):
        return getattr(obj, 'accepted_donors_count', obj.targets.filter(status='ACCEPTED').count())

    def get_escalation_status(self, obj):
        if obj.current_wave == 1:
            return f"Local Matching ({WAVE_RADIUS_KM.get(1, 5)}km)"
        elif obj.current_wave == 2:
            return f"District Escalation ({WAVE_RADIUS_KM.get(2, 25)}km)"
        elif obj.current_wave == 3:
            return f"Division Wide ({WAVE_RADIUS_KM.get(3, 100)}km)"
        else:
            return "National Emergency Broadcast"

    def get_hospital_name(self, obj):
        if obj.hospital:
            return obj.hospital.name
        return obj.hospital_name_other or obj.hospital_location
