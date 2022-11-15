import 'package:auto_route/auto_route.dart';
import 'package:boorusphere/constant/app.dart';
import 'package:boorusphere/data/repository/changelog/entity/changelog_option.dart';
import 'package:boorusphere/data/repository/changelog/entity/changelog_type.dart';
import 'package:boorusphere/data/repository/version/datasource/version_network_source.dart';
import 'package:boorusphere/data/repository/version/entity/app_version.dart';
import 'package:boorusphere/data/services/download.dart';
import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/provider/version.dart';
import 'package:boorusphere/presentation/routes/routes.dart';
import 'package:boorusphere/presentation/widgets/prepare_update.dart';
import 'package:boorusphere/utils/extensions/asyncvalue.dart';
import 'package:boorusphere/utils/extensions/buildcontext.dart';
import 'package:boorusphere/utils/extensions/number.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AboutPage extends HookConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentVer = ref.watch(versionCurrentProvider
        .select((it) => it.maybeValue ?? AppVersion.zero));
    final latestVer = ref.watch(versionLatestProvider);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.onBackground,
                ),
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.symmetric(vertical: 16),
                child: Image.asset(
                  'assets/icons/exported/logo.png',
                  height: 48,
                ),
              ),
              Text(
                'Boorusphere',
                style: context.theme.textTheme.headline6
                    ?.copyWith(fontWeight: FontWeight.w300),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Version $currentVer - $kAppArch',
                  style: context.theme.textTheme.subtitle2
                      ?.copyWith(fontWeight: FontWeight.w400),
                ),
              ),
              latestVer.when(
                data: (data) => data.isNewerThan(currentVer)
                    ? _Updater(data)
                    : ElevatedButton.icon(
                        onPressed: () => ref.refresh(versionLatestProvider),
                        style: ElevatedButton.styleFrom(elevation: 0),
                        icon: const Icon(Icons.done),
                        label: Text(t.updater.onLatest),
                      ),
                loading: () => ElevatedButton.icon(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(elevation: 0),
                  icon: Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(2.0),
                    child: const CircularProgressIndicator(),
                  ),
                  label: Text(t.updater.checking),
                ),
                error: (e, s) => ElevatedButton.icon(
                  onPressed: () => ref.refresh(versionLatestProvider),
                  style: ElevatedButton.styleFrom(elevation: 0),
                  icon: const Icon(Icons.update),
                  label: Text(t.updater.check),
                ),
              ),
              const Divider(height: 32),
              ListTile(
                title: Text(t.changelog.title),
                leading: const Icon(Icons.list_alt_rounded),
                onTap: () {
                  context.router.push(
                    ChangelogRoute(
                      option: const ChangelogOption(type: ChangelogType.assets),
                    ),
                  );
                },
              ),
              ListTile(
                title: Text(t.github),
                leading: const FaIcon(FontAwesomeIcons.github),
                onTap: () => launchUrlString(VersionNetworkSource.gitUrl,
                    mode: LaunchMode.externalApplication),
              ),
              ListTile(
                title: Text(t.ossLicense),
                leading: const Icon(Icons.collections_bookmark),
                onTap: () => context.router.push(const LicensesRoute()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Updater extends HookConsumerWidget {
  const _Updater(this.data);

  final AppVersion data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(t.updater.onNewVersion),
        ),
        _Downloader(version: data),
        ElevatedButton(
          onPressed: () {
            context.router.push(
              ChangelogRoute(
                option: ChangelogOption(
                  type: ChangelogType.git,
                  version: data,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(elevation: 0),
          child: Text(t.changelog.view),
        ),
      ],
    );
  }
}

class _Downloader extends HookConsumerWidget {
  const _Downloader({
    required this.version,
  });

  final AppVersion version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updater =
        ref.watch(downloadProvider.select((it) => it.appUpdateProgress));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (updater.status.isCanceled ||
            updater.status.isFailed ||
            updater.status.isEmpty)
          ElevatedButton(
            onPressed: () {
              ref
                  .read(downloadProvider)
                  .updater(action: UpdaterAction.start, version: version);
            },
            style: ElevatedButton.styleFrom(elevation: 0),
            child: Text(t.updater.download(version: version)),
          ),
        if (updater.status.isDownloading) ...[
          const SizedBox(width: 16),
          Padding(
              padding: const EdgeInsets.all(8),
              child: Text('${updater.progress}%')),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  LinearProgressIndicator(
                    value: updater.progress.ratio,
                    minHeight: 16,
                  ),
                  Shimmer(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        context.colorScheme.primary.withOpacity(0),
                        context.colorScheme.primary.withOpacity(0.5),
                        context.colorScheme.primary.withOpacity(0),
                      ],
                      stops: const <double>[
                        0.35,
                        0.5,
                        0.65,
                      ],
                    ),
                    period: const Duration(milliseconds: 700),
                    child: const LinearProgressIndicator(
                      value: 0,
                      minHeight: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(downloadProvider).updater(action: UpdaterAction.stop);
            },
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 16),
        ],
        if (updater.status.isDownloaded)
          ElevatedButton(
            onPressed: () {
              UpdatePrepareDialog.show(context);
            },
            child: Text(t.updater.install),
          ),
      ],
    );
  }
}