import sys

with open('blood_pulse/android/app/build.gradle.kts', 'r') as f:
    text = f.read()

# Add properties reading before plugins
props_reading = """
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

"""

if "keystoreProperties" not in text:
    text = text.replace("android {", props_reading + "android {\n    signingConfigs {\n        create(\"release\") {\n            keyAlias = keystoreProperties[\"keyAlias\"] as String?\n            keyPassword = keystoreProperties[\"keyPassword\"] as String?\n            storeFile = keystoreProperties[\"storeFile\"]?.let { file(it as String) }\n            storePassword = keystoreProperties[\"storePassword\"] as String?\n        }\n    }\n")
    text = text.replace("signingConfig = signingConfigs.getByName(\"debug\")", "signingConfig = signingConfigs.getByName(\"release\")")
    
    with open('blood_pulse/android/app/build.gradle.kts', 'w') as f:
        f.write(text)
    print("Updated build.gradle.kts")
