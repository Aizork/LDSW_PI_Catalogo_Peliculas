import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';
import 'auth_screen.dart';
import 'admin_screen.dart';
import 'tmdb_service.dart';

// Colores principales de CineApp.
const fondo = Color(0xFF0B1019);
const panel = Color(0xFF192231);
const rojo = Color(0xFFF04452);
const grisTexto = Color(0xFFB1BAC9);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CineApp());
}

class CineApp extends StatelessWidget {
  const CineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: fondo,
        colorScheme: const ColorScheme.dark(
          primary: rojo,
          surface: panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: fondo,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const AuthGate(child: PantallaInicio()),
    );
  }
}

// Catalogo y navegacion principal.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  late final Future<List<dynamic>> peliculasFuture;
  int pestana = 0;
  String busqueda = '';

  @override
  void initState() {
    super.initState();
    peliculasFuture = TmdbService.obtenerPeliculas();
  }

  void mostrarDetalle(Map<String, dynamic> pelicula) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaDetalle(pelicula: pelicula),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Inicia sesión.')));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('administradores')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final esAdmin = snapshot.data?.data()?['activo'] == true;
        final indiceActual = !esAdmin && pestana == 3 ? 0 : pestana;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 18,
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_movies_rounded, color: rojo, size: 29),
                SizedBox(width: 8),
                Text('CineApp', style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            actions: [
              PopupMenuButton<int>(
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu_rounded),
                onSelected: (opcion) => setState(() => pestana = opcion),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 0, child: Text('Catálogo')),
                  const PopupMenuItem(value: 1, child: Text('Mis favoritos')),
                  const PopupMenuItem(value: 2, child: Text('Cuenta')),
                  if (esAdmin)
                    const PopupMenuItem(value: 3, child: Text('Administración')),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: IndexedStack(
            index: indiceActual,
            children: [
              construirCatalogo(),
              construirFavoritos(),
              construirCuenta(),
              if (esAdmin) const PantallaAdministracion(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            backgroundColor: panel,
            indicatorColor: rojo.withValues(alpha: 0.22),
            selectedIndex: indiceActual,
            onDestinationSelected: (indice) => setState(() => pestana = indice),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: rojo),
                label: 'Inicio',
              ),
              const NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite, color: rojo),
                label: 'Favoritos',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: rojo),
                label: 'Cuenta',
              ),
              if (esAdmin)
                const NavigationDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: Icon(Icons.admin_panel_settings, color: rojo),
                  label: 'Admin',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget construirCatalogo() {
    return FutureBuilder<List<dynamic>>(
      future: peliculasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: rojo));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudieron cargar las peliculas.\n${snapshot.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }

        final todas = (snapshot.data ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final peliculas = todas.where((p) {
          return (p['title'] ?? '')
              .toString()
              .toLowerCase()
              .contains(busqueda);
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
              'Tu próxima gran película comienza aquí.',
              style: TextStyle(fontSize: 14, color: grisTexto),
            ),
            const SizedBox(height: 18),
            TextField(
              onChanged: (texto) => setState(() {
                busqueda = texto.trim().toLowerCase();
              }),
              decoration: InputDecoration(
                hintText: 'Buscar entre las películas mostradas...',
                hintStyle: const TextStyle(color: grisTexto, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: grisTexto),
                filled: true,
                fillColor: panel,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            construirSeccionAdministradas(),
            if (busqueda.isEmpty && todas.isNotEmpty) ...[
              const SizedBox(height: 20),
              construirDestacada(todas.first),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: rojo, size: 23),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Populares ahora',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${peliculas.length} títulos',
                    style: const TextStyle(color: grisTexto, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),
            if (peliculas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 35),
                child: Text('No encontramos películas con ese título.',
                    textAlign: TextAlign.center),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.62,
                ),
                itemCount: peliculas.length,
                itemBuilder: (_, i) => construirTarjeta(peliculas[i]),
              ),
            const SizedBox(height: 24),
            const Text(
              'Este producto utiliza la API de TMDB, pero no está avalado ni certificado por TMDB.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: grisTexto),
            ),
          ],
        );
      },
    );
  }

  // Catálogo que el administrador agrega en Firestore.
  Widget construirSeccionAdministradas() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('catalogo').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('No se pudo cargar el catálogo de Firebase.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: rojo));
        }
        final documentos = snapshot.data!.docs.where((doc) {
          final titulo = (doc.data()['titulo'] ?? '').toString().toLowerCase();
          return titulo.contains(busqueda);
        }).toList();
        if (documentos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.library_add_check, color: rojo),
                SizedBox(width: 8),
                Text('Agregadas a CineApp',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.62,
              ),
              itemCount: documentos.length,
              itemBuilder: (context, i) =>
                  TarjetaPeliculaManual(documento: documentos[i]),
            ),
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }

  Widget construirDestacada(Map<String, dynamic> pelicula) {
    final ruta = pelicula['backdrop_path']?.toString();
    final imagen = ruta != null && ruta.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w780$ruta'
        : TmdbService.obtenerPoster(pelicula['poster_path']?.toString());

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 225,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imagen.isNotEmpty
                ? Image.network(imagen, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: panel))
                : Container(color: panel),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xEF050910)],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: rojo,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('DESTACADA',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pelicula['title']?.toString() ?? 'Película destacada',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => mostrarDetalle(pelicula),
                    style: FilledButton.styleFrom(
                        backgroundColor: rojo, foregroundColor: Colors.white),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Ver detalles'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget construirTarjeta(Map<String, dynamic> pelicula) {
    final titulo = pelicula['title']?.toString() ?? 'Sin título';
    final poster = TmdbService.obtenerPoster(pelicula['poster_path']?.toString());
    final fecha = pelicula['release_date']?.toString() ?? '';
    final anio = fecha.isEmpty ? 'Sin fecha' : fecha.split('-').first;

    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => mostrarDetalle(pelicula),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: poster.isEmpty
                    ? const Icon(Icons.movie_rounded, size: 50, color: grisTexto)
                    : Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined, size: 44),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(anio, style: const TextStyle(color: grisTexto, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget construirFavoritos() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Inicia sesión para ver tus favoritos.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .collection('peliculas')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('No se pudieron cargar los favoritos.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: rojo));
        }
        final peliculas = snapshot.data!.docs;
        if (peliculas.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border, color: rojo, size: 58),
                SizedBox(height: 12),
                Text('Todavía no guardas películas.'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: peliculas.length,
          itemBuilder: (context, i) {
            final datos = peliculas[i].data();
            final poster = datos['imagenUrl']?.toString() ?? '';
            final tmdbId = datos['tmdbId'];
            return Card(
              color: panel,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(10),
                leading: SizedBox(
                  width: 55,
                  height: 75,
                  child: poster.isEmpty
                      ? const Icon(Icons.movie_outlined, color: grisTexto)
                      : Image.network(poster, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.movie_outlined)),
                ),
                title: Text(datos['titulo']?.toString() ?? 'Sin título'),
                subtitle: Text(datos['anio']?.toString() ?? ''),
                trailing: const Icon(Icons.chevron_right, color: rojo),
                onTap: tmdbId is num
                    ? () => mostrarDetalle({'id': tmdbId.toInt()})
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetallePeliculaManual(
                              datos: datos,
                              id: peliculas[i].id,
                            ),
                          ),
                        ),
              ),
            );
          },
        );
      },
    );
  }

  Widget construirCuenta() {
    final usuario = FirebaseAuth.instance.currentUser;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined, size: 70, color: rojo),
            const SizedBox(height: 14),
            const Text('Mi cuenta',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              usuario?.email ?? 'Usuario sin correo',
              textAlign: TextAlign.center,
              style: const TextStyle(color: grisTexto),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                    // AuthGate mostrara la pantalla de acceso.
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No se pudo cerrar sesión: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TMDB: detalles, géneros y equipo de producción.
Future<Map<String, dynamic>> consultarDetalles(int id) async {
  final url = Uri.parse(
    'https://api.themoviedb.org/3/movie/$id?language=es-MX&append_to_response=credits',
  );
  final respuesta = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer ${TmdbService.token}',
      'accept': 'application/json',
    },
  );
  if (respuesta.statusCode != 200) {
    throw Exception('No se pudieron consultar los detalles (${respuesta.statusCode}).');
  }
  return Map<String, dynamic>.from(jsonDecode(respuesta.body) as Map);
}

class PantallaDetalle extends StatefulWidget {
  final Map<String, dynamic> pelicula;
  const PantallaDetalle({super.key, required this.pelicula});

  @override
  State<PantallaDetalle> createState() => _PantallaDetalleState();
}

class _PantallaDetalleState extends State<PantallaDetalle> {
  late final Future<Map<String, dynamic>> detallesFuture;
  bool guardando = false;

  @override
  void initState() {
    super.initState();
    detallesFuture = consultarDetalles((widget.pelicula['id'] as num).toInt());
  }

  Future<void> guardarEnFirebase(
    Map<String, dynamic> pelicula,
    String director,
    String genero,
    String poster,
  ) async {
    if (guardando) return;
    setState(() => guardando = true);
    try {
      final usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) throw Exception('No hay una sesión activa.');

      final fecha = pelicula['release_date']?.toString() ?? '';
      final anio = fecha.isNotEmpty ? fecha.split('-').first : '';
      final id = (pelicula['id'] as num).toInt();

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('peliculas')
          .doc('tmdb_$id')
          .set({
        'tmdbId': id,
        'titulo': pelicula['title']?.toString() ?? '',
        'anio': anio,
        'director': director,
        'genero': genero,
        'sinopsis': pelicula['overview']?.toString() ?? '',
        'imagenUrl': poster,
        'favorito': true,
        'fechaRegistro': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Película guardada en Firebase!')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalles de película')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: detallesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: rojo));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No se pudieron consultar los detalles.\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }

          final pelicula = snapshot.data!;
          final fecha = pelicula['release_date']?.toString() ?? '';
          final anio = fecha.isEmpty ? 'N/D' : fecha.split('-').first;
          final generos = (pelicula['genres'] as List? ?? [])
              .map((g) => g['name']?.toString() ?? '')
              .where((g) => g.isNotEmpty)
              .join(', ');
          final equipo = (pelicula['credits']?['crew'] as List?) ?? [];
          String director = 'No disponible';
          for (final persona in equipo) {
            if (persona['job'] == 'Director') {
              director = persona['name']?.toString() ?? director;
              break;
            }
          }
          final poster = TmdbService.obtenerPoster(
            pelicula['poster_path']?.toString(),
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (poster.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    poster,
                    height: 310,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.movie_outlined, size: 95),
                  ),
                ),
              const SizedBox(height: 22),
              Text(
                pelicula['title']?.toString() ?? 'Sin título',
                style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Año: $anio')),
                  Chip(label: Text(generos.isEmpty ? 'Sin género' : generos)),
                ],
              ),
              const SizedBox(height: 12),
              Text('Director: $director',
                  style: const TextStyle(fontSize: 16, color: grisTexto)),
              const SizedBox(height: 22),
              const Text('Sinopsis',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                (pelicula['overview']?.toString().isNotEmpty ?? false)
                    ? pelicula['overview'].toString()
                    : 'Sin sinopsis disponible.',
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 25),
              FilledButton.icon(
                onPressed: guardando
                    ? null
                    : () => guardarEnFirebase(pelicula, director, generos, poster),
                style: FilledButton.styleFrom(
                  backgroundColor: rojo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                icon: Icon(guardando ? Icons.hourglass_top : Icons.favorite),
                label: Text(guardando ? 'Guardando...' : 'Guardar en favoritos'),
              ),
              const SizedBox(height: 18),
              const Text(
                'Información proporcionada por TMDB. Este producto utiliza la API de TMDB, '
                'pero no está avalado ni certificado por TMDB.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: grisTexto),
              ),
            ],
          );
        },
      ),
    );
  }
}
