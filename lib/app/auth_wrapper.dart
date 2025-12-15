
// class AuthWrapper extends StatelessWidget {
//   const AuthWrapper({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final AuthService authService = AuthService();
//
//     return StreamBuilder<User?>(
//       stream: authService.userChanges,
//       builder: (context, snapshot) {
//         // Mostra un caricamento mentre si verifica lo stato
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }
//
//         // Se l'utente è loggato, mostra la schermata principale
//         if (snapshot.hasData) {
//           return const AppScaffoldMobile();
//         }
//
//         // Altrimenti, mostra la pagina di accesso
//         return const AuthPageMobile();
//       },
//     );
//   }
// }
