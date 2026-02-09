import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../wallet/presentation/pages/create_wallet_page.dart';
import '../../../wallet/presentation/pages/import_wallet_page.dart';
import '../../../../../utils/I10n.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);

    return AppScaffold(
      backgroundColor: AppColors.background,
      statusBarIconBrightness: Brightness.light,
      useSafeArea: false,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 3),

            Hero(
              tag: 'logo_hero',
              child: Image.asset(
                'assets/images/scash-logo.png',
                width: 110, // 稍微调整大小比例
                height: 110,
              ),
            ),

            const SizedBox(height: 48),

            // 标题
            Text(
              loc.t('app_intro'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.8,
              ),
            ),

            const SizedBox(height: 16),

            // 描述文字
            Text(
              loc.t('create_or_add_wallet'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),

            const Spacer(flex: 4),

            // 创建钱包按钮
            _buildPrimaryButton(
              context,
              label: loc.t('create_wallet'),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateWalletPage()),
                );
              },
            ),

            const SizedBox(height: 16),

            // 导入钱包按钮
            _buildSecondaryButton(
              context,
              label: loc.t('import_wallet'),
              onPressed: () {
                HapticFeedback.lightImpact(); // 较轻的反馈
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ImportWalletPage()),
                );
              },
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // 主按钮构建逻辑
  Widget _buildPrimaryButton(BuildContext context, {required String label, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.button,
          borderRadius: AppRadii.pill,
          boxShadow: [
            BoxShadow(
              color: AppColors.button.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // 次按钮构建逻辑
  Widget _buildSecondaryButton(BuildContext context, {required String label, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadii.pill,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}