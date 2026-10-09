import 'package:dyspatch_app/Features/Home/widget/delivery_cards.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';

class DeliveryTypeScreen extends StatefulWidget {
  const DeliveryTypeScreen({super.key});

  @override
  State<DeliveryTypeScreen> createState() => _DeliveryTypeScreenState();
}

class _DeliveryTypeScreenState extends State<DeliveryTypeScreen> {
  String _selected = (Session.instance.user?['default_delivery_type'] as String?) ?? 'standard'; // 'standard' or 'express'

  Future<void> _set(String v) async {
    final old = _selected;
    setState(() => _selected = v);
    try {
      await DyspatchApi.updateMe({'default_delivery_type': v});
    } catch (e) {
      if (mounted) {
        setState(() => _selected = old);
        toast(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Delivery type",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            SizedBox(height: 30),

            // ── Body ─────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Choose your default delivery type",
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Standard card
                    DeliveryCards(
                      title: "Standard",
                      features: const ["Cheaper", "Avg of 60 - 120 mins"],
                      isSelected: _selected == 'standard',
                      onToggle: (val) {
                        if (val) _set('standard');
                      },
                    ),

                    const SizedBox(height: 16),

                    // Express card
                    DeliveryCards(
                      title: "Express",
                      features: const ["Expensive", "Avg of 20 - 40 mins"],
                      isSelected: _selected == 'express',
                      onToggle: (val) {
                        if (val) _set('express');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
