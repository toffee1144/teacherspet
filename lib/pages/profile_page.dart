import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    const teacherName = 'Mr. Probz';
    const subject = 'Mathematics & Science';
    const email = 'probz67@gmail.com';
    const phone = '+62 67676767676767';
    const school = 'Mentari intercultural school Jakarta';
    const about =
        'Passionate about inspiring students to love learning. 10+ years of experience in teaching Mathematics and Science. Enjoys robotics, chess, and outdoor activities.';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // avatar
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.blue.shade200,
                  child: Text(
                    teacherName.split(' ').map((e) => e[0]).take(2).join(),
                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 18),
                // name
                Text(
                  teacherName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 6),
                // subjct
                Text(
                  subject,
                  style: TextStyle(fontSize: 16, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 18),
                // Info Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.school, color: Colors.blue, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(school, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.email, color: Colors.blue, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(email, style: const TextStyle(fontSize: 15)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.blue, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(phone, style: const TextStyle(fontSize: 15)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // abt
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    about,
                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
