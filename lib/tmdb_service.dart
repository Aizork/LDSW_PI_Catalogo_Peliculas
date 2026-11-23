
import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  static const String token =
  String.fromEnvironment('TMDB_TOKEN');

  // Consultar peliculas populares
  static Future<List<dynamic>> obtenerPeliculas() async {
    if (token.isEmpty) {
      throw Exception('Falta configurar el token de TMDB');
    }

    final url = Uri.parse(
      'https://api.themoviedb.org/3/movie/popular'
          '?language=es-MX&region=MX&page=1',
    );

    final respuesta = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'accept': 'application/json',
      },
    );

    if (respuesta.statusCode == 200) {
      final datos = jsonDecode(respuesta.body);
      return datos['results'] as List<dynamic>;
    } else {
      throw Exception(
        'Error al consultar peliculas: ${respuesta.statusCode}',
      );
    }
  }

  // Obtener la imagen de cada pelicula
  static String obtenerPoster(String? ruta) {
    if (ruta == null || ruta.isEmpty) {
      return '';
    }

    return 'https://image.tmdb.org/t/p/w500$ruta';
  }
}
