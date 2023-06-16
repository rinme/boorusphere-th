import 'package:boorusphere/data/provider.dart';
import 'package:boorusphere/data/repository/booru/entity/page_option.dart';
import 'package:boorusphere/data/repository/booru/parser/gelbooru_xml_parser.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:boorusphere/data/repository/server/user_server_repo.dart';
import 'package:boorusphere/domain/provider.dart';
import 'package:boorusphere/main.dart';
import 'package:boorusphere/presentation/provider/server_data_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import '../../presentation/state/app_version_test.dart';
import '../../utils/dio.dart';
import '../../utils/fake_data.dart';
import '../../utils/hive.dart';
import '../../utils/mocktail.dart';
import '../../utils/riverpod.dart';

void main() async {
  setupLogger();
  setupMocktailFallbacks();
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gelbooru', () async {
    final ref = ProviderContainer(overrides: [
      defaultServersProvider.overrideWithValue(await provideDefaultServers()),
      envRepoProvider.overrideWithValue(FakeEnvRepo()),
    ]);

    initializeTestHive();
    addTearDown(() async {
      await destroyTestHive();
      ref.dispose();
    });

    await UserServerRepo.prepare();
    ref.setupTestFor(dioProvider);
    final adapter = DioAdapterMock.on(ref.read(dioProvider));

    ref.setupTestFor(serverRepoProvider);
    await ref.read(serverRepoProvider).populate();

    final server = ref.read(serverRepoProvider).servers.getById('Gelbooru');
    ref.setupTestFor(imageboardRepoProvider(server));

    const option = PageOption(limit: 5);
    final okHeaders = {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    };

    final fakePage = getFakeData('gelbooru/posts.json').readAsStringSync();
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((x) async =>
        ResponseBody.fromString(fakePage, 200, headers: okHeaders));

    expect(
      await ref.read(imageboardRepoProvider(server)).getPage(option, 1),
      isA<Iterable>().having((x) => x.length, 'total', option.limit - 2),
      reason: 'expecting 2 invalid post',
    );

    final fakeTags = getFakeData('gelbooru/tags.json').readAsStringSync();
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        ResponseBody.fromString(fakeTags, 200, headers: okHeaders));

    expect(
      await ref.read(imageboardRepoProvider(server)).getSuggestion('book'),
      isA<Iterable>()
          .having((x) => x.length, 'total', Server.tagSuggestionLimit - 2),
      reason: 'expecting 2 tags with zero post_count',
    );

    final okHeadersXml = {
      Headers.contentTypeHeader: ['text/xml']
    };
    final parser = GelbooruXmlParser();
    final serverXml = ref
        .read(serverRepoProvider)
        .servers
        .getById('Gelbooru')
        .copyWith(
            searchUrl: parser.searchQuery,
            tagSuggestionUrl: parser.suggestionQuery);
    ref.setupTestFor(imageboardRepoProvider(serverXml));

    final fakePageXml = getFakeData('gelbooru/posts.xml').readAsStringSync();
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((x) async =>
        ResponseBody.fromString(fakePageXml, 200, headers: okHeadersXml));

    expect(
      await ref.read(imageboardRepoProvider(server)).getPage(option, 1),
      isA<Iterable>().having((x) => x.length, 'total', option.limit - 2),
      reason: 'expecting 2 invalid post',
    );

    final fakeTagsXml = getFakeData('gelbooru/tags.xml').readAsStringSync();
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        ResponseBody.fromString(fakeTagsXml, 200, headers: okHeadersXml));

    expect(
      await ref.read(imageboardRepoProvider(server)).getSuggestion('book'),
      isA<Iterable>()
          .having((x) => x.length, 'total', Server.tagSuggestionLimit - 2),
      reason: 'expecting 2 tags with zero post_count',
    );
  });
}