import 'dart:convert';

import 'package:http/http.dart' as http;

import 'update_models.dart';

const _repoOwner = 'D-A-W-N';
const _repoName = 'qwirkel-digital';

class GithubReleaseClient {
  GithubReleaseClient(this._client);

  final http.Client _client;

  Future<GithubRelease> fetchLatestRelease() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
    );
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'qwirkle-digital-updater',
      },
    );

    if (response.statusCode != 200) {
      throw GithubReleaseException(
        'GitHub-Release-Abfrage fehlgeschlagen (${response.statusCode}).',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw GithubReleaseException('Antwort der GitHub-API war unlesbar.');
    }

    return GithubRelease.fromJson(json);
  }
}

class GithubReleaseException implements Exception {
  GithubReleaseException(this.message);

  final String message;

  @override
  String toString() => message;
}
