import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quick_recipe/Utils/constants.dart';
import 'package:quick_recipe/Widgets/my_icon_button.dart';

class StepScreen extends StatefulWidget {
  final DocumentSnapshot documentSnapshot;

  const StepScreen({super.key, required this.documentSnapshot});

  @override
  State<StepScreen> createState() => _StepScreenState();
}

class _StepScreenState extends State<StepScreen> {
  int currentStep = 0;

  late List<dynamic> steps;

  @override
  void initState() {
    super.initState();

    final data = widget.documentSnapshot.data() as Map<String, dynamic>;

    steps = data['step'] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    // No steps
    if (steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cooking Steps')),
        body: const Center(child: Text('No cooking steps available.')),
      );
    }

    final bool isLastStep = currentStep == steps.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,

      // top bar
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Hero(
              tag: widget.documentSnapshot['image'],
              child: Container(
                height: MediaQuery.of(context).size.height / 3,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: NetworkImage(widget.documentSnapshot['image']),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 45,
            left: 10,
            child: MyIconButton(
              icon: Icons.arrow_back_ios_new,
              pressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          Positioned.fill(
            top: MediaQuery.of(context).size.height / 3 - 25,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),

              child: Column(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: isLastStep ? Colors.green : kprimaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${currentStep + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    isLastStep ? 'Final Step' : 'Step ${currentStep + 1}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isLastStep ? Colors.green : Colors.black,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: Text(
                          steps[currentStep].toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM BAR
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),

              child: Column(
                children: [
                  // Progress text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${currentStep + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        '${steps.length} Steps',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: (currentStep + 1) / steps.length,
                      ),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          color: kprimaryColor,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      // BACK
                      Expanded(
                        child: OutlinedButton(
                          onPressed: currentStep == 0
                              ? null
                              : () {
                                  setState(() {
                                    currentStep--;
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Back'),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isLastStep) {
                              Navigator.pop(context);
                            } else {
                              setState(() {
                                currentStep++;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLastStep
                                ? Colors.green
                                : kprimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isLastStep ? 'Finish Cooking' : 'Next',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
