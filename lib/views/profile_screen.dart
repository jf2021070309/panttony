import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../core/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userId = auth.userId;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, auth),
          SliverToBoxAdapter(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('usuarios').doc(userId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(50.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('No se encontró información del perfil.'));
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final role = auth.currentUserRole ?? UserRole.cliente;

                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildInfoCard(userData, role),
                      const SizedBox(height: 20),
                      _buildActionButtons(context, auth, role),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AuthProvider auth) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: AppColors.primary),
              ),
              const SizedBox(height: 10),
              Text(
                auth.userName ?? 'Usuario',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> data, UserRole role) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.email, 'Email', data['email'] ?? 'No disponible'),
          const Divider(height: 30),
          _buildInfoRow(Icons.phone, 'Teléfono', data['phone'] ?? 'No disponible'),
          const Divider(height: 30),
          _buildInfoRow(Icons.verified_user, 'Rol', _getRoleName(role)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, AuthProvider auth, UserRole role) {
    return Column(
      children: [
        if (role == UserRole.repartidor)
          _buildMenuButton(Icons.history, 'Historial de Entregas', () {}),
        if (role == UserRole.cliente)
          _buildMenuButton(Icons.location_on, 'Mis Direcciones', () {}),
        if (role == UserRole.admin)
          _buildMenuButton(Icons.settings, 'Configuración del Sistema', () {}),
        
        const SizedBox(height: 10),
        
        _buildMenuButton(
          Icons.logout, 
          'Cerrar Sesión', 
          () => auth.logout(), 
          isDanger: true
        ),
      ],
    );
  }

  Widget _buildMenuButton(IconData icon, String title, VoidCallback onTap, {bool isDanger = false}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isDanger ? Colors.red : AppColors.primary),
        title: Text(
          title,
          style: TextStyle(
            color: isDanger ? Colors.red : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.admin: return 'Administrador';
      case UserRole.repartidor: return 'Repartidor';
      case UserRole.cliente: return 'Cliente';
    }
  }
}
