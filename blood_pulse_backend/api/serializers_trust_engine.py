from rest_framework import serializers
from api.models import BloodRequest
from api.conf import (
    TRUST_SCORE_BASE, TRUST_SCORE_HOSPITAL_VERIFIED, 
    TRUST_SCORE_PRESCRIPTION_SLIP, TRUST_SCORE_NO_SHOW_PENALTY
)

class QuarantineQueueSerializer(serializers.ModelSerializer):
    ocr_match_percent = serializers.SerializerMethodField()
    anomaly_signal = serializers.SerializerMethodField()
    geo_proximity = serializers.SerializerMethodField()
    requester_id = serializers.IntegerField(source='requester.id', read_only=True)
    
    class Meta:
        model = BloodRequest
        fields = [
            'id', 'patient_name', 'blood_group', 'trust_score', 'trust_band',
            'ocr_match_percent', 'anomaly_signal', 'geo_proximity', 'created_at',
            'requester_id'
        ]
        
    def get_ocr_match_percent(self, obj):
        # ⚠️ UI Feature Promised: OCR match %. 
        # The underlying logic (Gemini vision slip verification) currently returns a strict 
        # True/False/None dict in verify_slip_with_ai. There is no confidence interval % 
        # or OCR matrix saved to the DB. Faking this is disabled.
        return None
        
    def get_anomaly_signal(self, obj):
        # ⚠️ UI Feature Promised: IMEI clustering / Sybil detection stream.
        # The codebase does not track device hardware IDs, IMEI clustering, 
        # or advanced Sybil graph logic. Faking this is disabled.
        return None
        
    def get_geo_proximity(self, obj):
        # Base model has 'geohash' but we'd need the reviewer's/donor's hash to do a proximity diff.
        return None

class TrustWeightConfigSerializer(serializers.Serializer):
    base_score = serializers.IntegerField(default=50)
    hospital_verified = serializers.IntegerField(default=15)
    prescription_slip = serializers.IntegerField(default=20)
    no_show_penalty = serializers.IntegerField(default=25)
