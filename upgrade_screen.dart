// lib/screens/upgrade_screen.dart (New File - Placeholder)
import 'package:flutter/material.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  Widget _buildTierCard(BuildContext context, String title, String price, List<String> features, Color color, {bool isRecommended = false}) {
    return Card(
      elevation: isRecommended ? 8.0 : 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: isRecommended ? BorderSide(color: Theme.of(context).primaryColorDark, width: 2) : BorderSide.none,
      ),
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (isRecommended)
              Chip(
                label: const Text('Recommended'),
                backgroundColor: Theme.of(context).primaryColor,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            if (isRecommended) const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              price,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 15),
            const Divider(),
            const SizedBox(height: 10),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_outline, color: Colors.green[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(feature, style: const TextStyle(fontSize: 16))),
                ],
              ),
            )).toList(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Placeholder for purchase logic
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Purchase option for $title coming soon!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 15.0),
                textStyle: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              child: const Text('Choose Plan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Your Plan'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          const Text(
            'Choose the plan that\'s right for you!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          _buildTierCard(
            context,
            'Free',
            'Free Forever',
            [
              '7 Story Generations per week',
              '7 Public Story Views per week',
              'Basic Persona Creation',
            ],
            Colors.grey.shade600,
          ),
          _buildTierCard(
            context,
            'Premium',
            '\$4.99 / month (Example)', // Placeholder price
            [
              '30 Story Generations per week',
              'Unlimited Public Story Views',
              'Advanced Persona Features',
              'Access to Premium Voices (Coming Soon)',
              'Priority Support',
            ],
            Theme.of(context).primaryColor,
            isRecommended: true,
          ),
          _buildTierCard(
            context,
            'Unlimited',
            '\$9.99 / month (Example)', // Placeholder price
            [
              'Unlimited Story Generations',
              'Unlimited Public Story Views',
              'All Persona Features',
              'Custom Voice Cloning (Coming Soon)',
              'All Premium Voices (Coming Soon)',
              'Dedicated Support',
            ],
            Colors.deepOrangeAccent,
          ),
           const SizedBox(height: 20),
           Text(
            'Note: Pricing and features are illustrative and subject to change. Payments will be handled via app store subscriptions (not yet implemented).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}