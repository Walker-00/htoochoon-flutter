# We exclude the obsolete firebase-iid module (it duplicates classes in
# firebase-messaging 24.x). ML Kit's optional "linkfirebase" path references
# FirebaseInstanceId, but we only use bundled base models (not Firebase-hosted
# models), so that path is dead — tell R8 not to error on the missing class.
-dontwarn com.google.firebase.iid.**
-dontwarn com.google.mlkit.linkfirebase.**
