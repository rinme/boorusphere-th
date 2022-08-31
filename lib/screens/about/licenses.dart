import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../routes/slide_page.dart';
import '../../utils/extensions/buildcontext.dart';

final _registryProvider = FutureProvider((ref) async {
  final data = await LicenseRegistry.licenses.fold<LicenseData>(
    LicenseData(),
    (prev, license) => prev..add(license),
  );
  return data.toMap();
});

class LicenseData {
  final _packages = <String>{};
  final _licenses = <LicenseEntry>[];

  void add(LicenseEntry entry) {
    for (final String package in entry.packages) {
      _packages.add(package);
    }
    _licenses.add(entry);
  }

  Map<String, Iterable<LicenseEntry>> toMap() {
    return Map.fromEntries(_packages.sorted().map(
        (it) => MapEntry(it, _licenses.where((e) => e.packages.contains(it)))));
  }
}

class LicensesPage extends HookConsumerWidget {
  const LicensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(_registryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Open Source Licenses')),
      body: SafeArea(
        child: registry.maybeWhen(
          data: (data) {
            return ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: data.length,
              itemBuilder: (context, index) {
                final packageName = data.keys.elementAt(index);
                final packageLicenses = data.values.elementAt(index);
                final count = packageLicenses.length;
                return ListTile(
                  title: Text(packageName),
                  subtitle: Text('$count license${count > 1 ? 's' : ''}'),
                  onTap: () {
                    PackageLicenses.display(
                      context: context,
                      packageLicenses: packageLicenses,
                      packageName: packageName,
                    );
                  },
                );
              },
            );
          },
          orElse: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: LinearProgressIndicator(),
            ),
          ),
        ),
      ),
    );
  }
}

class PackageLicenses extends StatelessWidget {
  const PackageLicenses({
    super.key,
    required this.packageName,
    required this.packageLicenses,
  });

  final String packageName;
  final Iterable<LicenseEntry> packageLicenses;

  @override
  Widget build(BuildContext context) {
    final count = packageLicenses.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('License${count > 1 ? 's' : ''}'),
        centerTitle: true,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text('package: $packageName'))),
      ),
      body: ListView.separated(
        itemCount: packageLicenses.length,
        padding: const EdgeInsets.all(22),
        itemBuilder: (context, index) {
          final license = packageLicenses.elementAt(index);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in license.paragraphs)
                if (p.indent == LicenseParagraph.centeredIndent)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(p.text, textAlign: TextAlign.center),
                  )
                else
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      top: 8.0,
                      start: 16.0 * p.indent,
                    ),
                    child: Text(p.text),
                  ),
            ],
          );
        },
        separatorBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 32),
            child: SizedBox(
              width: 72,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: context.colorScheme.primary),
              ),
            ),
          );
        },
      ),
    );
  }

  static void display({
    required BuildContext context,
    required String packageName,
    required Iterable<LicenseEntry> packageLicenses,
  }) {
    context.navigator.push(
      SlidePageRoute(
        builder: (context) => PackageLicenses(
          packageName: packageName,
          packageLicenses: packageLicenses,
        ),
      ),
    );
  }
}
