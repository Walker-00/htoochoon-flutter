/// Legal copy shown inside the app (Terms of Service + Privacy Policy) and
/// surfaced from the pre-exam proctoring consent sheet.
///
/// Kept as plain strings (lightweight markdown: `#`/`##` headings, `- ` bullets)
/// so no asset bundling / pubspec wiring is needed. The same text lives at the
/// repo root in TERMS_OF_SERVICE.md / PRIVACY_POLICY.md for the record.
library;

const String kLegalLastUpdated = 'June 15, 2026';

const String termsOfServiceMd = '''
# Terms of Service

_Last updated: ${kLegalLastUpdated}_

## 1. Acceptance
By using this learning platform you agree to these Terms. If you do not agree,
do not use the app.

## 2. Accounts
You are responsible for keeping your account credentials secure and for all
activity under your account. Provide accurate information when registering.

## 3. Acceptable use
You agree not to misuse the platform, including attempting to access content you
are not enrolled in, disrupting service, or interfering with other users.

## 4. Exams and academic integrity
Exams may be proctored. When you take a proctored exam you agree to:
- stay inside the app for the duration of the exam;
- not switch to other apps, open split-view, or place another app over the exam;
- keep your face visible and stay alone (if camera proctoring is enabled);
- keep the exam network guard enabled (if network proctoring is enabled);
- not use unauthorized materials or assistance.

Leaving the app during an exam is recorded. A short absence produces a warning
and is added to an integrity score; a long absence ends the exam automatically.
If you grant camera and microphone access, your behaviour during the exam (such
as no face visible, multiple people, looking away, or talking) is analysed on
your device and contributes to the integrity score. The integrity score is
advisory information for your teacher or administrator — it does not by itself
change your grade. Your instructor reviews flagged exams and decides any outcome.

## 5. Content
Course materials, questions, and submissions belong to their respective owners.
Do not copy, redistribute, or publish exam content.

## 6. Availability
The platform is provided "as is". We may change or suspend features at any time.

## 7. Termination
We may suspend accounts that violate these Terms or academic-integrity rules.

## 8. Contact
Questions about these Terms can be sent to your organization's administrator.
''';

const String privacyPolicyMd = '''
# Privacy Policy

_Last updated: ${kLegalLastUpdated}_

## 1. What we collect
- **Account data**: name, email, role, and organization membership.
- **Learning data**: enrollments, submissions, grades, and activity needed to
  run your courses.
- **App-focus proctoring data** (during a proctored exam): whether the app stays
  in the foreground, and for each time you leave the app — a timestamp and how
  long you were away.
- **Camera proctoring data** (during a proctored exam, if you grant camera
  access): your device's front camera is analysed **on your device** to detect
  behaviour such as no face in view, multiple people, or looking away. We record
  only the resulting **events** (the kind of behaviour, a timestamp, how long it
  lasted, and the head angle) — not images.
- **Microphone proctoring data** (during a proctored exam, if you grant
  microphone access): audio loudness is analysed **on your device** to detect
  sustained talking. We record only that a voice event occurred and how long it
  lasted.
- **Network-guard data** (during a proctored exam, on supported devices): with
  your permission a local on-device VPN is enabled that blocks *other* apps from
  the internet while you take the exam. We record only whether this guard was on
  or off and any times it was turned off — not the contents of any traffic.

From all of the above we compute an advisory integrity score (0–100).

## 2. What we do NOT do
- We do **not** upload, store, or transmit camera images or video of you.
- We do **not** upload, store, or transmit microphone audio recordings.
- All camera and microphone analysis happens **on your device**; only the
  derived events and score leave your device with your submission.
- The network guard only **blocks** other apps during the exam — we do **not**
  inspect, log, or store the contents of your network traffic.

## 3. How proctoring data is used
The integrity score, the behaviour-event timeline (app-focus, camera,
microphone, and network-guard events), and their durations are sent to your
teacher and your organization's administrators so they can review exam
integrity. This information is advisory and does not automatically change grades.

## 4. Sharing
Your data is visible to your organization's teachers and administrators as needed
to operate your courses. We do not sell your personal data.

## 5. Retention
Proctoring signals are stored with the related exam submission for as long as the
submission is retained by your organization.

## 6. Your choices
Before starting a proctored exam you are shown what is monitored and must agree
to continue. If you do not agree, you can decline and not take the exam through
the app.

## 7. Contact
For privacy questions, contact your organization's administrator.
''';
