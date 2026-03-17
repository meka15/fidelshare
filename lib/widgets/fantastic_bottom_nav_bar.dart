import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class FantasticBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onChatPressed;

  const FantasticBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onChatPressed,
  });

  @override
  State<FantasticBottomNavBar> createState() => _FantasticBottomNavBarState();
}

class _FantasticBottomNavBarState extends State<FantasticBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _itemAnimations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _itemAnimations = List.generate(4, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.15,
            0.6 + index * 0.1,
            curve: Curves.easeInOutBack,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 102,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.95),
                        AppColors.surfaceLight.withOpacity(0.98),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(35),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.15),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.1),
                        blurRadius: 40,
                        offset: const Offset(-5, 15),
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) {
                      final tab = TabConfig.tabs[index];
                      final isSelected = widget.selectedIndex == index;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onDestinationSelected(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.elasticOut,
                            margin: EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primaryBlue.withOpacity(0.1),
                                        AppColors.secondaryBlue.withOpacity(
                                          0.05,
                                        ),
                                      ],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _itemAnimations[index],
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: isSelected
                                          ? 1.0 +
                                                (_itemAnimations[index].value *
                                                    0.08)
                                          : 1.0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: isSelected
                                            ? BoxDecoration(
                                                gradient: RadialGradient(
                                                  colors: [
                                                    AppColors.primaryBlue
                                                        .withOpacity(0.2),
                                                    Colors.transparent,
                                                  ],
                                                  radius: 0.8,
                                                ),
                                              )
                                            : null,
                                        child: Icon(
                                          TabConfig.getIcon(
                                            tab,
                                            selected: isSelected,
                                          ),
                                          color: isSelected
                                              ? AppColors.primaryBlue
                                              : AppColors.textSecondary,
                                          size: isSelected ? 24 : 22,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -_animationController.value * 5),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.fabGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentPurple.withOpacity(0.4),
                            blurRadius: 20 + (_animationController.value * 10),
                            offset: const Offset(0, 8),
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: AppColors.accentPink.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(-5, 12),
                            spreadRadius: 0,
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onChatPressed,
                          borderRadius: BorderRadius.circular(35),
                          splashColor: Colors.white.withOpacity(0.3),
                          highlightColor: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                                radius: 0.7,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    return Container(
                                      width:
                                          60 + (_animationController.value * 8),
                                      height:
                                          60 + (_animationController.value * 8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.accentPurple
                                            .withOpacity(
                                              0.2 -
                                                  _animationController.value *
                                                      0.1,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _animationController.value * 0.2,
                                      child: const Icon(
                                        Icons.chat_bubble_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
