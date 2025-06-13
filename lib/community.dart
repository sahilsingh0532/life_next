// community.dart - Main Communities Page

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'country_page.dart';

class CommunitiesPage extends StatefulWidget {
  const CommunitiesPage({Key? key}) : super(key: key);

  @override
  _CommunitiesPageState createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<CountryInfo> countries = [
    CountryInfo(
      name: "India",
      colors: [
        Color(0xFFFF9933),
        Color.fromARGB(255, 0, 0, 0),
        Color(0xFF138808)
      ],
      image: 'assets/india.jpg',
    ),
    CountryInfo(
      name: "China",
      colors: [Color(0xFFDE2910), Color(0xFFFFDE00)],
      image: 'assets/china.jpg',
    ),
    CountryInfo(
      name: "Japan",
      colors: [Color.fromARGB(255, 106, 199, 0), Color(0xFFBC002D)],
      image: 'assets/japan.jpg',
    ),
    CountryInfo(
      name: "South Korea",
      colors: [
        Color.fromARGB(255, 0, 183, 255),
        Color(0xFF0047A0),
        Color(0xFFCD2E3A)
      ],
      image: 'assets/south_korea.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Communities Page',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: countries.map((country) {
          int index = countries.indexOf(country);
          return _buildCountrySection(country, index);
        }).toList(),
      ),
    );
  }

  Widget _buildCountrySection(CountryInfo country, int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final Animation<Offset> slideAnimation = Tween<Offset>(
          begin: Offset(index.isEven ? -1.0 : 1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _controller,
          curve: Interval(index * 0.1, 0.3 + index * 0.1,
              curve: Curves.easeOutCubic),
        ));

        return SlideTransition(
          position: slideAnimation,
          child: child,
        );
      },
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  CountryPage(country: country),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
            ),
          );
        },
        child: Container(
          height: MediaQuery.of(context).size.height * 0.2,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(country.image),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.4),
                BlendMode.darken,
              ),
            ),
            border: Border(
              bottom: index < countries.length - 1
                  ? BorderSide(color: Colors.white, width: 2.0)
                  : BorderSide.none,
            ),
          ),
          child: Center(
            child: Text(
              country.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CountryInfo {
  final String name;
  final List<Color> colors;
  final String image;

  CountryInfo({
    required this.name,
    required this.colors,
    required this.image,
  });
}
