import logging
import os
from django.conf import settings

logger = logging.getLogger(__name__)

def send_blood_request_notification(request_data):
    """
    Utility function to trigger high-priority push notifications to donors
    via the Firebase Admin SDK when a new urgent blood request is created.

    Parameters:
        request_data (dict or BloodRequest instance): Data containing details of the blood request.

    Returns:
        bool: True if sent successfully, False otherwise.
    """
    try:
        import firebase_admin
        from firebase_admin import messaging, credentials
    except ImportError:
        logger.warning("firebase-admin is not installed. Push notification skipped.")
        return False

    try:
        # Initialize Firebase Admin App if not already initialized
        if not firebase_admin._apps:
            cred_path = getattr(settings, "FIREBASE_CREDENTIALS_PATH", os.getenv("GOOGLE_APPLICATION_CREDENTIALS"))
            if cred_path and os.path.exists(cred_path):
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
            else:
                firebase_admin.initialize_app()
    except Exception as init_err:
        logger.warning(f"Firebase Admin app initialization warning: {init_err}")

    try:
        # Extract fields whether request_data is a dict or model instance
        if isinstance(request_data, dict):
            blood_group = request_data.get("blood_group", "Blood")
            patient_name = request_data.get("patient_name", "A patient")
            hospital_location = request_data.get("hospital_location", "a nearby hospital")
            urgency_level = request_data.get("urgency_level", "Urgent")
            request_id = str(request_data.get("id", ""))
        else:
            blood_group = getattr(request_data, "blood_group", "Blood")
            patient_name = getattr(request_data, "patient_name", "A patient")
            hospital_location = getattr(request_data, "hospital_location", "a nearby hospital")
            urgency_level = getattr(request_data, "urgency_level", "Urgent")
            request_id = str(getattr(request_data, "id", ""))

        title = f"Urgent: {blood_group} Blood Needed!"
        body = f"{urgency_level} request for {patient_name} at {hospital_location}."

        # Format topic to match target donor group, e.g. blood_group_a_pos or general
        safe_group = blood_group.replace("+", "_pos").replace("-", "_neg").lower()
        topic = f"blood_group_{safe_group}"

        # High priority FCM message configuration
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                "type": "BLOOD_REQUEST",
                "request_id": request_id,
                "blood_group": str(blood_group),
                "urgency_level": str(urgency_level),
                "hospital_location": str(hospital_location),
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="blood_pulse_emergency_channel",
                    priority="max",
                    default_sound=True,
                ),
            ),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        content_available=True,
                    )
                ),
            ),
            topic=topic,
        )

        response = messaging.send(message)
        logger.info(f"FCM notification dispatched successfully. Message ID: {response}")
        return True

    except Exception as e:
        logger.error(f"Failed to dispatch FCM notification: {e}")
        return False

