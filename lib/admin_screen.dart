import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _fondo = Color(0xFF0B1019);
const _panel = Color(0xFF192231);
const _rojo = Color(0xFFF04452);
const _gris = Color(0xFFB1BAC9);

// Pantalla visible únicamente para usuarios autorizados en Firestore.
// La seguridad real se aplica con firestore.rules, no con esta pantalla.
class PantallaAdministracion extends StatefulWidget {
  const PantallaAdministracion({super.key});

  @override
  State<PantallaAdministracion> createState() => _PantallaAdministracionState();
}

class _PantallaAdministracionState extends State<PantallaAdministracion> {
  final _formKey = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _anio = TextEditingController();
  final _director = TextEditingController();
  final _genero = TextEditingController();
  final _sinopsis = TextEditingController();
  final _imagen = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _anio.dispose();
    _director.dispose();
    _genero.dispose();
    _sinopsis.dispose();
    _imagen.dispose();
    super.dispose();
  }

  String? _requerido(String? texto) {
    if ((texto ?? '').trim().isEmpty) return 'Campo obligatorio';
    return null;
  }

  Future<void> _agregarPelicula() async {
    if (_guardando || !_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Debes iniciar sesión.');
      await FirebaseFirestore.instance.collection('catalogo').add({
        'titulo': _titulo.text.trim(),
        'anio': int.parse(_anio.text.trim()),
        'director': _director.text.trim(),
        'genero': _genero.text.trim(),
        'sinopsis': _sinopsis.text.trim(),
        'imagenUrl': _imagen.text.trim(),
        'creadoPor': uid,
        'fechaRegistro': FieldValue.serverTimestamp(),
      });
      _titulo.clear();
      _anio.clear();
      _director.clear();
      _genero.clear();
      _sinopsis.clear();
      _imagen.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Película agregada al catálogo de Firebase.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminarPelicula(String id, String titulo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar película'),
        content: Text('¿Quieres eliminar “$titulo” del catálogo compartido?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _rojo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await FirebaseFirestore.instance.collection('catalogo').doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Película eliminada de Firebase.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $error')),
      );
    }
  }

  Widget _campo(
    String nombre,
    TextEditingController controlador, {
    int lineas = 1,
    TextInputType? teclado,
    String? Function(String?)? validar,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controlador,
        maxLines: lineas,
        keyboardType: teclado,
        validator: validar ?? _requerido,
        decoration: InputDecoration(
          labelText: nombre,
          filled: true,
          fillColor: _panel,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: _rojo, size: 30),
            SizedBox(width: 8),
            Text('Administración',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Da de alta o elimina películas del catálogo compartido.',
            style: TextStyle(color: _gris)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Agregar película',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _campo('Título', _titulo),
                _campo(
                  'Año de estreno', _anio,
                  teclado: TextInputType.number,
                  validar: (valor) {
                    final anio = int.tryParse((valor ?? '').trim());
                    if (anio == null || anio < 1888 || anio > 2100) {
                      return 'Escribe un año válido (1888 a 2100)';
                    }
                    return null;
                  },
                ),
                _campo('Director', _director),
                _campo('Género', _genero),
                _campo('Sinopsis', _sinopsis, lineas: 3),
                _campo(
                  'URL de la imagen (https://...)', _imagen,
                  teclado: TextInputType.url,
                  validar: (valor) {
                    final uri = Uri.tryParse((valor ?? '').trim());
                    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
                      return 'Pega una URL de imagen HTTPS válida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: _guardando ? null : _agregarPelicula,
                  style: FilledButton.styleFrom(
                    backgroundColor: _rojo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: Icon(_guardando ? Icons.hourglass_top : Icons.add),
                  label: Text(_guardando ? 'Guardando...' : 'Agregar a CineApp'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Películas agregadas en Firebase',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('catalogo').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('No fue posible cargar las películas. Revisa las reglas de Firestore.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: _rojo));
            }
            final documentos = snapshot.data!.docs;
            if (documentos.isEmpty) {
              return const Text('Todavía no hay películas agregadas manualmente.',
                  style: TextStyle(color: _gris));
            }
            return Column(
              children: documentos.map((doc) {
                final datos = doc.data();
                final titulo = datos['titulo']?.toString() ?? 'Sin título';
                return Card(
                  color: _panel,
                  child: ListTile(
                    title: Text(titulo),
                    subtitle: Text('${datos['anio'] ?? ''} · ${datos['director'] ?? ''}'),
                    trailing: IconButton(
                      tooltip: 'Eliminar película',
                      icon: const Icon(Icons.delete_outline, color: _rojo),
                      onPressed: () => _eliminarPelicula(doc.id, titulo),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// Tarjeta de películas agregadas por el administrador, visibles a todos.
class TarjetaPeliculaManual extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> documento;
  const TarjetaPeliculaManual({super.key, required this.documento});

  @override
  Widget build(BuildContext context) {
    final datos = documento.data();
    final poster = datos['imagenUrl']?.toString() ?? '';
    final titulo = datos['titulo']?.toString() ?? 'Sin título';
    return Material(
      color: _panel,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetallePeliculaManual(
              datos: datos, id: documento.id,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: poster.isEmpty
                    ? const Icon(Icons.movie_rounded, color: _gris, size: 50)
                    : Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined, size: 45),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${datos['anio'] ?? ''}',
                      style: const TextStyle(color: _gris, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Detalle de película manual; se puede guardar en favoritos personales.
class DetallePeliculaManual extends StatefulWidget {
  final Map<String, dynamic> datos;
  final String id;
  const DetallePeliculaManual({super.key, required this.datos, required this.id});

  @override
  State<DetallePeliculaManual> createState() => _DetallePeliculaManualState();
}

class _DetallePeliculaManualState extends State<DetallePeliculaManual> {
  bool _guardando = false;

  Future<void> _guardarFavorito() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Inicia sesión.');
      final datos = widget.datos;
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .collection('peliculas')
          .doc('manual_${widget.id}')
          .set({
        'titulo': datos['titulo'] ?? '',
        'anio': datos['anio']?.toString() ?? '',
        'director': datos['director'] ?? '',
        'genero': datos['genero'] ?? '',
        'sinopsis': datos['sinopsis'] ?? '',
        'imagenUrl': datos['imagenUrl'] ?? '',
        'favorito': true,
        'fechaRegistro': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Película guardada en tus favoritos.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = widget.datos;
    final poster = datos['imagenUrl']?.toString() ?? '';
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(title: const Text('Detalles de película')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (poster.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(poster, height: 300, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.movie_outlined, size: 85)),
            ),
          const SizedBox(height: 18),
          Text(datos['titulo']?.toString() ?? 'Sin título',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Año: ${datos['anio'] ?? 'N/D'}'),
          Text('Director: ${datos['director'] ?? 'N/D'}'),
          Text('Género: ${datos['genero'] ?? 'N/D'}'),
          const SizedBox(height: 18),
          const Text('Sinopsis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(datos['sinopsis']?.toString() ?? 'Sin sinopsis'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardarFavorito,
            style: FilledButton.styleFrom(backgroundColor: _rojo),
            icon: const Icon(Icons.favorite),
            label: Text(_guardando ? 'Guardando...' : 'Guardar en favoritos'),
          ),
        ],
      ),
    );
  }
}
