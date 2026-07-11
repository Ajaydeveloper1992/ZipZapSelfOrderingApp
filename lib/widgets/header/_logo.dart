import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HeaderLogo extends StatelessWidget {
  final String? logoUrl;

  const HeaderLogo({
    super.key,
    this.logoUrl,
  });

  Future<void> _launchLogoUrl() async {
    final url = logoUrl ?? 'https://zipzappos.com';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _launchLogoUrl,
      child: SvgPicture.asset(
        'assets/images/zipzap-icon.svg',
        width: 38,
        height: 38,
      ),
    );
  }
}

