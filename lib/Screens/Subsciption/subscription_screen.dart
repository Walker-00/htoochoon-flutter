import 'package:flutter/material.dart';

import '../../Widgets/in_development_badge.dart';

// ── Data Models ──────────────────────────────────────────────────────────────

class PlanPrice {
  final double? monthly;
  final double? yearly;
  const PlanPrice({this.monthly, this.yearly});
}

class PlanLimits {
  final dynamic maxStudents;
  final dynamic maxTeachers;
  final dynamic maxPrograms;
  final dynamic maxCourses;
  final dynamic maxClasses;
  final dynamic maxStorageGB;
  const PlanLimits({
    required this.maxStudents,
    required this.maxTeachers,
    required this.maxPrograms,
    required this.maxCourses,
    required this.maxClasses,
    required this.maxStorageGB,
  });
}

class PlanTier {
  final String planType;
  final String name;
  final String description;
  final PlanPrice price;
  final List<String> features;
  final PlanLimits limits;
  final bool isCurrent;
  final bool canUpgrade;
  final bool contactSales;

  const PlanTier({
    required this.planType,
    required this.name,
    required this.description,
    required this.price,
    required this.features,
    required this.limits,
    required this.isCurrent,
    required this.canUpgrade,
    this.contactSales = false,
  });
}

// ── Mock Data ─────────────────────────────────────────────────────────────────

final List<PlanTier> mockPlans = [
  PlanTier(
    planType: 'FREE',
    name: 'Free Plan',
    description: 'Perfect for getting started! 🌱',
    price: const PlanPrice(monthly: 0, yearly: 0),
    features: [
      'Up to 50 students',
      'Up to 5 teachers',
      '3 programs',
      'Basic analytics',
      'Community support',
    ],
    limits: const PlanLimits(
      maxStudents: 50,
      maxTeachers: 5,
      maxPrograms: 3,
      maxCourses: 10,
      maxClasses: 20,
      maxStorageGB: 5,
    ),
    isCurrent: true,
    canUpgrade: true,
  ),
  PlanTier(
    planType: 'BASIC',
    name: 'Basic Plan',
    description: 'Great for small teams! 👥',
    price: const PlanPrice(monthly: 29, yearly: 290),
    features: [
      'Up to 200 students',
      'Up to 20 teachers',
      '10 programs',
      'Advanced analytics',
      'Live sessions (10 hrs/mo)',
      'Email support',
    ],
    limits: const PlanLimits(
      maxStudents: 200,
      maxTeachers: 20,
      maxPrograms: 10,
      maxCourses: 50,
      maxClasses: 100,
      maxStorageGB: 25,
    ),
    isCurrent: false,
    canUpgrade: true,
  ),
  PlanTier(
    planType: 'PRO',
    name: 'Pro Plan',
    description: 'For growing organizations! 🚀',
    price: const PlanPrice(monthly: 99, yearly: 990),
    features: [
      'Up to 1,000 students',
      'Up to 100 teachers',
      '50 programs',
      'Full analytics suite',
      'Unlimited live sessions',
      'Custom domain',
      'Priority support',
    ],
    limits: const PlanLimits(
      maxStudents: 1000,
      maxTeachers: 100,
      maxPrograms: 50,
      maxCourses: 200,
      maxClasses: 500,
      maxStorageGB: 100,
    ),
    isCurrent: false,
    canUpgrade: true,
  ),
  PlanTier(
    planType: 'ENTERPRISE',
    name: 'Enterprise Plan',
    description: 'Custom solutions for large orgs! 🏢',
    price: const PlanPrice(monthly: null, yearly: null),
    features: [
      'Unlimited everything! ✨',
      'SSO/SAML integration',
      'Dedicated account manager',
      'Custom integrations',
      'SLA guarantees',
      'On-premise option',
    ],
    limits: const PlanLimits(
      maxStudents: 'Unlimited',
      maxTeachers: 'Unlimited',
      maxPrograms: 'Unlimited',
      maxCourses: 'Unlimited',
      maxClasses: 'Unlimited',
      maxStorageGB: 'Unlimited',
    ),
    isCurrent: false,
    canUpgrade: true,
    contactSales: true,
  ),
];

// ── Theme Constants ───────────────────────────────────────────────────────────

class AppColors {
  static const Color primary = Color(0xFF0D7B6E); // Teal
  static const Color primaryLight = Color(0xFF14A699);
  static const Color background = Color(0xFFF7F9FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0F5F4);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color borderLight = Color(0xFFE5EAF0);
  static const Color proBorder = Color(0xFF0D7B6E);
  static const Color badgeBg = Color(0xFF0D7B6E);
  static const Color currentPlanBg = Color(0xFFEFF7F6);
  static const Color featureCheck = Color(0xFF0D7B6E);
  static const Color roiAccent = Color(0xFF0D7B6E);
  static const Color upgradeBtn = Color(0xFF0D7B6E);
  static const Color compareLabelPro = Color(0xFF0D7B6E);
}

// ── Subscription Screen ───────────────────────────────────────────────────────

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with TickerProviderStateMixin {
  bool _isYearly = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildBillingToggle(),
              _buildPlanCards(),
              _buildROIInsight(),
              _buildCompareTable(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.textSecondary,
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'Subscription',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: false,
      actions: [
        _NavItem(label: 'Dashboard', isActive: false),
        _NavItem(label: 'Courses', isActive: false),
        _NavItem(label: 'Subscription', isActive: true),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: const Icon(
              Icons.person_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        children: [
          const Text(
            'Empower Your Institution',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose a plan that scales with your learning community.\nUnlock advanced AI capabilities and institutional management tools.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Billing Toggle ──────────────────────────────────────────────────────────

  Widget _buildBillingToggle() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ToggleLabel(label: 'Monthly', isActive: !_isYearly),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => _isYearly = !_isYearly),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 46,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: _isYearly ? AppColors.primary : AppColors.borderLight,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: _isYearly
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              _ToggleLabel(label: 'Yearly', isActive: _isYearly),
              const SizedBox(width: 6),
              if (_isYearly)
                AnimatedOpacity(
                  opacity: _isYearly ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Save 17%',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Plan Cards ──────────────────────────────────────────────────────────────

  Widget _buildPlanCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Top row: FREE + PRO (PRO is "Most Popular")
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PlanCard(plan: mockPlans[0], isYearly: _isYearly),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlanCard(
                  plan: mockPlans[2],
                  isYearly: _isYearly,
                  isMostPopular: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom row: BASIC + ENTERPRISE
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PlanCard(plan: mockPlans[1], isYearly: _isYearly),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlanCard(plan: mockPlans[3], isYearly: _isYearly),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ROI Insight ─────────────────────────────────────────────────────────────

  Widget _buildROIInsight() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI ROI Insight',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 8),
              const InDevelopmentBadge(),
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
                height: 1.3,
              ),
              children: [
                TextSpan(text: 'Organizations on Pro plans see a '),
                TextSpan(
                  text: '35% increase',
                  style: TextStyle(color: AppColors.roiAccent),
                ),
                TextSpan(text: ' in teacher efficiency.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Our advanced AI grading suite automates repetitive assessments, allowing educators to focus on personalized student mentoring and curriculum design.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _AvatarStack(),
              const SizedBox(width: 10),
              const Text(
                'Joined by 200+ Institutions',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Compare Table ───────────────────────────────────────────────────────────

  Widget _buildCompareTable() {
    final rows = [
      _CompareRow(
        label: 'AI Assessment',
        starter: 'Basic',
        pro: 'Advanced Logic',
        isProHighlight: true,
      ),
      _CompareRow(
        label: 'Custom Domains',
        starter: 'No',
        pro: 'Yes',
        isProHighlight: true,
      ),
      _CompareRow(
        label: 'Data Export',
        starter: 'CSV only',
        pro: 'API & Webhooks',
        isProHighlight: true,
      ),
      _CompareRow(
        label: 'Storage',
        starter: '10GB',
        pro: '1TB',
        isProHighlight: true,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              'Compare Plan Features',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return _CompareRowWidget(row: e.value, isLast: isLast);
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final String label;
  final bool isActive;
  const _NavItem({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ToggleLabel extends StatelessWidget {
  final String label;
  final bool isActive;
  const _ToggleLabel({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        color: isActive ? AppColors.textPrimary : AppColors.textMuted,
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanTier plan;
  final bool isYearly;
  final bool isMostPopular;

  const _PlanCard({
    required this.plan,
    required this.isYearly,
    this.isMostPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFree = plan.planType == 'FREE';
    final bool isEnterprise = plan.planType == 'ENTERPRISE';
    final bool isCurrent = plan.isCurrent;

    final double? price = isYearly ? plan.price.yearly : plan.price.monthly;

    return Container(
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.currentPlanBg
            : isMostPopular
            ? AppColors.surface
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMostPopular
              ? AppColors.proBorder
              : isCurrent
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.borderLight,
          width: isMostPopular ? 2 : 1,
        ),
        boxShadow: isMostPopular
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Most Popular badge
          if (isMostPopular)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(
                color: AppColors.badgeBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Text(
                'MOST POPULAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan type label
                Text(
                  plan.planType,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isMostPopular
                        ? AppColors.primary
                        : AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),

                // Price
                if (isEnterprise)
                  const Text(
                    'Custom',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  )
                else if (isFree)
                  const Text(
                    'Free',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${price!.toInt()}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text(
                          '/mo',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 6),

                // Description
                Text(
                  plan.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 14),

                // Features
                ...plan.features
                    .take(5)
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 15,
                              height: 15,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.featureCheck.withValues(alpha: 0.12),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 9,
                                color: AppColors.featureCheck,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                f,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                const SizedBox(height: 16),

                // CTA Button
                _PlanButton(plan: plan, isMostPopular: isMostPopular),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  final PlanTier plan;
  final bool isMostPopular;
  const _PlanButton({required this.plan, required this.isMostPopular});

  @override
  Widget build(BuildContext context) {
    if (plan.isCurrent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Text(
          'Current Plan',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    if (plan.contactSales) {
      return GestureDetector(
        onTap: () => showComingSoonSnackBar(context, 'Contact Sales'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: const Text(
            'Contact Sales',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => showComingSoonSnackBar(context, 'Plan upgrades'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isMostPopular ? AppColors.upgradeBtn : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: isMostPopular
              ? null
              : Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          isMostPopular ? 'Upgrade Now' : 'Upgrade',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isMostPopular ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final List<Color> _colors = const [
    Color(0xFFFF7878),
    Color(0xFF78B4FF),
    Color(0xFF78DFAB),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 28,
      child: Stack(
        children: List.generate(3, (i) {
          return Positioned(
            left: i * 18.0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _colors[i],
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CompareRow {
  final String label;
  final String starter;
  final String pro;
  final bool isProHighlight;
  const _CompareRow({
    required this.label,
    required this.starter,
    required this.pro,
    this.isProHighlight = false,
  });
}

class _CompareRowWidget extends StatelessWidget {
  final _CompareRow row;
  final bool isLast;
  const _CompareRowWidget({required this.row, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.borderLight, width: 1),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Starter: ${row.starter}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Pro: ${row.pro}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: row.isProHighlight
                    ? AppColors.compareLabelPro
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
