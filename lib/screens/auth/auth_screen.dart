import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../widgets/psn_button.dart';
import '../../widgets/psn_divider.dart';
import '../../widgets/psn_text_field.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Tokens.spaceXl),
            Text(
              'Welcome back',
              style: tt.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Tokens.spaceSm),
            Text(
              'Sign in to sync your sessions across devices.',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: Tokens.spaceXl),
            PSNTextField(
              placeholder: 'Email address',
              prefixIcon: Icons.email_outlined,
            ),
            const SizedBox(height: Tokens.spaceSm),
            PSNTextField(
              placeholder: 'Password',
              prefixIcon: Icons.lock_outline,
            ),
            const SizedBox(height: Tokens.spaceMd),
            PSNButton(
              label: 'Sign In',
              fullWidth: true,
              onTap: () {
                // TODO: implement auth
              },
            ),
            const SizedBox(height: Tokens.spaceLg),
            const PSNDivider(label: 'or'),
            const SizedBox(height: Tokens.spaceLg),
            PSNButton(
              label: 'Continue with Apple',
              variant: ButtonVariant.secondary,
              fullWidth: true,
              icon: Icon(Icons.apple, color: cs.onSurface, size: 22),
              onTap: () {
                // TODO: implement Apple sign in
              },
            ),
          ],
        ),
      ),
    );
  }
}
