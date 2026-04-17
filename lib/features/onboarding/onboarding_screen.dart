import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../routes/navigation.dart';
import '../../routes/routes.dart';
import '../dashboard/dashboard_providers.dart';
import 'onboarding_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibilityAndNavigate();
    }
  }

  Future<void> _checkAccessibilityAndNavigate() async {
    final curPage = ref.read(onboardingPageProvider);
    if (curPage == 3) {
      final platform = ref.read(dashboardPlatformProvider);
      final bool enabled = await platform.invokeMethod('isAccessibilityEnabled');
      if (enabled) {
        await ref.read(onboardingNotifierProvider.notifier).completeOnboarding();
        Navigation.instance.pushNamedAndRemoveUntil(AppRoutes.dashboard);
      }
    }
  }

  void _nextPage() {
    if (_pageController.page! < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      );
    } else {
      _openAccessibilitySettings();
    }
  }

  void _openAccessibilitySettings() {
    ref.read(dashboardPlatformProvider).invokeMethod('openAccessibilitySettings');
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() {
    _pageController.jumpToPage(3);
    ref.read(onboardingPageProvider.notifier).state = 3;
  }

  @override
  Widget build(BuildContext context) {
    final curPage = ref.watch(onboardingPageProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0B101A),
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00FFD1).withOpacity(0.05),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00FFD1).withOpacity(0.1), blurRadius: 100),
                ],
              ),
            ),
          ),
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              ref.read(onboardingPageProvider.notifier).state = index;
            },
            physics: const BouncingScrollPhysics(),
            children: [
              _PageOneDigitalDouble(onNext: _nextPage, onLearn: () {}),
              _PageTwoNoCloud(onNext: _nextPage, onBack: _prevPage),
              _PageThreeHardware(onNext: _nextPage, onBack: _prevPage),
              _PageFourPermissions(onEnable: _openAccessibilitySettings, onSkip: _nextPage),
            ],
          ),
          _buildHeader(curPage),
        ],
      ),
    );
  }

  Widget _buildHeader(int curPage) {
    bool isSentinelMode = curPage == 1 || curPage == 2;
    String titleText = isSentinelMode ? 'SENTINEL AI' : 'TWINY AI';
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (!isSentinelMode)
                  Image.asset('assets/twiny.png', width: 20, height: 20, color: const Color(0xFF00FFD1))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .shimmer(duration: 2.seconds, color: Colors.white)
                else
                  const Icon(Icons.shield_outlined, color: Color(0xFF00FFD1), size: 20)
                      .animate().fadeIn().scale(),
                const SizedBox(width: 8),
                Text(
                  titleText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                    fontSize: 13,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 500.ms),
            if (curPage == 0)
              IconButton(onPressed: () {}, icon: const Icon(Icons.menu, color: Colors.white))
                .animate().fadeIn()
            else if (curPage == 1 || curPage == 2)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  iconSize: 20,
                  onPressed: () {},
                  icon: const Icon(Icons.question_mark, color: Colors.grey),
                ),
              ).animate().fadeIn()
            else if (curPage == 3)
              TextButton(
                onPressed: _skip,
                child: const Text('SKIP', style: TextStyle(color: Colors.grey, letterSpacing: 1.2)),
              ).animate().fadeIn()
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE COMPONENTS
// -----------------------------------------------------------------------------

class _CyanButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final IconData? suffixIcon;

  const _CyanButton({required this.onPressed, required this.text, this.suffixIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF3BFFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3BFFFF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF0B101A),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            if (suffixIcon != null) ...[
              const SizedBox(width: 8),
              Icon(suffixIcon, color: const Color(0xFF0B101A), size: 20),
            ]
          ],
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const _OutlinedButton({required this.onPressed, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;
  final VoidCallback? onNext;

  const _PageIndicator({required this.count, required this.activeIndex, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: selectedNextButton() ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
      children: [
        if (selectedNextButton()) const SizedBox(width: 48), // Balance for centering dots if next button present
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (index) {
            bool isActive = index == activeIndex;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF3BFFFF) : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isActive
                    ? [BoxShadow(color: const Color(0xFF3BFFFF).withOpacity(0.5), blurRadius: 6)]
                    : null,
              ),
            );
          }),
        ),
        if (selectedNextButton())
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward, color: Color(0xFF3BFFFF), size: 20),
            ),
          )
      ],
    );
  }

  bool selectedNextButton() => onNext != null;
}

// -----------------------------------------------------------------------------
// PAGE 1: MEETYOUR DIGITAL DOUBLE
// -----------------------------------------------------------------------------

class _PageOneDigitalDouble extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onLearn;

  const _PageOneDigitalDouble({required this.onNext, required this.onLearn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 100),
          // Central Image Hero
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2A2D3A), Color(0xFF141724)],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: CustomPaint(painter: _StripesPainter()),
                      ),
                    ),
                  ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.9, 0.9)),
                  // Glass panel with fingerprint
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3BFFFF).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF3BFFFF).withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF3BFFFF).withOpacity(0.1), blurRadius: 20)
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.fingerprint, color: Color(0xFF3BFFFF), size: 48),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.05, 1.05)),
                  
                  // Floating Badge
                  Positioned(
                    top: 50,
                    right: -20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F2E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Color(0xFFFF52A2), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'NEURAL SYNCING...',
                            style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          )
                        ],
                      ),
                    ).animate().slideX(begin: 0.5, duration: 600.ms).fadeIn(),
                  ),
                ],
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ALPHA ACCESS 2.0',
              style: TextStyle(color: Color(0xFF3BFFFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ).animate().fadeIn(delay: 300.ms),
          
          const SizedBox(height: 24),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, height: 1.1, fontFamily: 'sans-serif'),
              children: [
                TextSpan(text: 'Meet Your\n', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'Digital Double', style: TextStyle(color: Color(0xFF3BFFFF))),
              ],
            ),
          ).animate().slideY(begin: 0.2).fadeIn(delay: 400.ms),
          
          const SizedBox(height: 16),
          Text(
            'Twiny learns your voice and style to\nmanage your communication\nseamlessly. Experience the next\nevolution of personal agency.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, height: 1.5),
          ).animate().fadeIn(delay: 500.ms),
          
          const SizedBox(height: 40),
          _CyanButton(text: 'Continue', onPressed: onNext).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          _OutlinedButton(text: 'Learn the Protocol', onPressed: onLearn).animate().fadeIn(delay: 800.ms),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _StripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    // draw diagonal lines
    for (int i = -100; i < size.width + size.height; i += 15) {
      canvas.drawLine(
        Offset(i.toDouble(), 0), 
        Offset(i.toDouble() - size.height, size.height), 
        paint
      );
    }
    
    // add some particles
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.2);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 2, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 1.5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.9), 1, dotPaint);
    
    // vertical splitting line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()..color = Colors.black.withOpacity(0.5)..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// PAGE 2: NO CLOUD STORAGE
// -----------------------------------------------------------------------------

class _PageTwoNoCloud extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _PageTwoNoCloud({required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 120),
          // Central Visual
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Diamond background lines
                Transform.rotate(
                  angle: 0.785, // 45 deg
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(16),
                      gradient: RadialGradient(colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.transparent
                      ]),
                    ),
                  ),
                ).animate().scale(duration: 800.ms).rotate(begin: -0.1),
                
                // Cyan Glow Center
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3BFFFF),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF3BFFFF).withOpacity(0.4), blurRadius: 30, spreadRadius: 5)
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_rounded, color: Color(0xFF0B101A), size: 40),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.05, 1.05), duration: 2.seconds),
                
                // Badges
                Positioned(
                  top: 70,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141A29),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: const Text(
                      'ENCRYPTED_VAULT',
                      style: TextStyle(color: Color(0xFF3BFFFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5),
                
                Positioned(
                  bottom: 70,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141A29),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: const Text(
                      'LOCAL_ONLY',
                      style: TextStyle(color: Color(0xFFFF52A2), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ).animate().fadeIn(delay: 700.ms).slideY(begin: -0.5),
              ],
            ),
          ),
          
          Text(
            'PRIVACY PROTOCOL',
            style: TextStyle(color: const Color(0xFFFF52A2).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3),
          ).animate().fadeIn(delay: 400.ms),
          
          const SizedBox(height: 16),
          const Text(
            'No Cloud Storage',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 500.ms),
          
          const SizedBox(height: 16),
          _PageIndicator(count: 3, activeIndex: 0),
          
          const SizedBox(height: 24),
          Text(
            'We never see your data. No servers, no\nlogs, no middle-men. Everything runs in a\nsecure local vault.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, height: 1.5),
          ).animate().fadeIn(delay: 600.ms),
          
          const SizedBox(height: 48),
          _CyanButton(
            text: 'CONTINUE',
            suffixIcon: Icons.arrow_forward,
            onPressed: onNext,
          ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PAGE 3: PROCESSED ON-DEVICE
// -----------------------------------------------------------------------------

class _PageThreeHardware extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _PageThreeHardware({required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 100),
          // Hardware Center Visual
          Expanded(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF3BFFFF).withOpacity(0.05), blurRadius: 40)
                  ],
                ),
                child: CustomPaint(
                  painter: _ChipPainter(),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B101A),
                        border: Border.all(color: const Color(0xFF3BFFFF), width: 2),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF3BFFFF).withOpacity(0.5), blurRadius: 20)
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3BFFFF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat()).shimmer(color: Colors.white.withOpacity(0.5), duration: 2.seconds),
                  ),
                ),
              ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.95, 0.95)),
            ),
          ),
          
          Text(
            'HARDWARE OPTIMIZATION',
            style: TextStyle(color: const Color(0xFFFF52A2).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3),
          ).animate().fadeIn(delay: 300.ms),
          
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, height: 1.1, fontFamily: 'sans-serif'),
              children: [
                TextSpan(text: 'Processed\n', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'On-Device', style: TextStyle(color: Color(0xFF3BFFFF), fontStyle: FontStyle.italic)),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms),
          
          const SizedBox(height: 24),
          Text(
            'Compute-intensive neural twinning\nhappens locally, leveraging your\nhardware\'s full potential without external\nlatency.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, height: 1.5),
          ).animate().fadeIn(delay: 500.ms),
          
          const SizedBox(height: 32),
          _PageIndicator(count: 3, activeIndex: 1, onNext: onNext).animate().fadeIn(delay: 600.ms),
          
          const SizedBox(height: 32),
          _CyanButton(
            text: 'INITIATE SEQUENCE',
            onPressed: onNext,
          ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3BFFFF).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
      
    double midX = size.width / 2;
    double midY = size.height / 2;
    double boxSize = 80;
    
    // Draw lines emerging from the center box
    for (int i = 0; i < 15; i++) {
      double startOffset = (boxSize/2) - 30 + (i * 4);
      
      // Top lines
      canvas.drawLine(Offset(midX - 30 + (i*4), midY - boxSize/2), Offset(midX - 30 + (i*4), 20), paint);
      // Bottom lines
      canvas.drawLine(Offset(midX - 30 + (i*4), midY + boxSize/2), Offset(midX - 30 + (i*4), size.height - 20), paint);
      // Left lines
      canvas.drawLine(Offset(midX - boxSize/2, midY - 30 + (i*4)), Offset(20, midY - 30 + (i*4)), paint);
      // Right lines
      canvas.drawLine(Offset(midX + boxSize/2, midY - 30 + (i*4)), Offset(size.width - 20, midY - 30 + (i*4)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// -----------------------------------------------------------------------------
// PAGE 4: SYSTEM PERMISSIONS
// -----------------------------------------------------------------------------

class _PageFourPermissions extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  const _PageFourPermissions({required this.onEnable, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 100),
            Text(
              'SECURITY PROTOCOL',
              style: TextStyle(color: const Color(0xFFFF52A2).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
            ).animate().fadeIn(delay: 200.ms),
            
            const SizedBox(height: 8),
            const Text(
              'System\nPermissions',
              style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, height: 1.1),
            ).animate().slideX(begin: -0.1).fadeIn(delay: 300.ms),
            
            const SizedBox(height: 16),
            Text(
              'To evolve into your digital double, Twiny requires specific access to interact with your digital environment.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, height: 1.5),
            ).animate().fadeIn(delay: 400.ms),
            
            const SizedBox(height: 32),
            
            _buildPermissionCard(
              icon: Icons.accessibility_new_rounded,
              title: 'Accessibility Access',
              desc: 'Twiny uses this to read and understand incoming messages in real-time, allowing it to learn your conversational patterns and intent.',
              badge: 'READ-ONLY MODE',
              badgeColor: const Color(0xFF3BFFFF),
              badgeIcon: Icons.verified_user_outlined,
              backgroundIcon: Icons.visibility,
              delay: 500,
            ),
            
            const SizedBox(height: 16),
            _buildPermissionCard(
              icon: Icons.hub, // Using hub instead of multistar
              title: 'Notification Access',
              desc: 'Enables seamless auto-replies and alert management. Twiny acts as your front-line filter, prioritizing what matters most.',
              badge: 'LOCAL PROCESSING',
              badgeColor: const Color(0xFFFF52A2),
              badgeIcon: Icons.lock_outline,
              backgroundIcon: Icons.notifications_none,
              delay: 600,
            ),
            
            const SizedBox(height: 16),
            _buildEndToEndCard(delay: 700),
            
            const SizedBox(height: 32),
            _CyanButton(
              text: 'Grant System Access',
              onPressed: onEnable,
            ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
            
            const SizedBox(height: 24),
            Center(
              child: Text(
                'SECURE DIGITAL TWIN PROTOCOL V2.4.0',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon, 
    required String title, 
    required String desc, 
    required String badge,
    required Color badgeColor,
    required IconData badgeIcon,
    required IconData backgroundIcon,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Icon(backgroundIcon, size: 80, color: Colors.white.withOpacity(0.02)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                desc,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B101A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, color: badgeColor, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      badge,
                      style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    )
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.1);
  }
  
  Widget _buildEndToEndCard({required int delay}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield, color: Color(0xFFE2E8F0), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text('End-To-End Privacy', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'All interaction data remains encrypted and stored strictly on your device. Twiny never transmits your private messages to external servers.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          )
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.1);
  }
}
