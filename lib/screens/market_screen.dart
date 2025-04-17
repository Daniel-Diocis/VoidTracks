import 'package:flutter/material.dart';

class MarketScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Miniatura dell’icona dell’app
            CircleAvatar(
              backgroundImage: AssetImage('assets/images/icon.png'),
              radius: 16,
            ),
            SizedBox(width: 8),
            Text("VoidMarket"),
          ],
        ),
      ),
      body: Center(
        child: Text("Questa sarà la schermata Market per Supabase", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}