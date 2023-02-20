import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/provider/server_data_state.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';
import 'package:boorusphere/presentation/provider/settings/server_setting_state.dart';
import 'package:boorusphere/presentation/provider/settings/ui_setting_state.dart';
import 'package:boorusphere/presentation/screens/home/drawer/home_drawer_controller.dart';
import 'package:boorusphere/presentation/screens/home/home_page.dart';
import 'package:boorusphere/presentation/screens/home/search/search_bar_controller.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:boorusphere/presentation/widgets/blur_backdrop.dart';
import 'package:boorusphere/presentation/widgets/favicon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SearchBar extends HookConsumerWidget {
  const SearchBar({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchBar = ref.watch(searchBarControllerProvider);
    final delta = useState([0.0, 0.0]);
    final collapsed = !searchBar.isOpen && delta.value.first > 0;
    final isBlurAllowed =
        ref.watch(uiSettingStateProvider.select((ui) => ui.blur));
    final imeIncognito =
        ref.watch(uiSettingStateProvider.select((it) => it.imeIncognito));
    final pageArgs = ref.watch(homePageArgsProvider);
    final server =
        ref.watch(serverDataStateProvider).getById(pageArgs.serverId);
    final onScrolling = useCallback(() {
      final position = scrollController.position;
      final threshold = SearchBar.innerHeight;
      if (delta.value.first > 0 &&
          position.viewportDimension > position.maxScrollExtent) {
        // reset back to default (!collapsed) because there's nothing to scroll
        delta.value = [0, 0];
        return;
      }

      if (position.extentBefore < threshold ||
          position.extentAfter < threshold) {
        // we're already at the edge of the scrollable content
        // there's no need to change the collapsed state
        return;
      }

      final current = position.pixels;
      final offset = (delta.value.first + current - delta.value.last);
      final boundary = offset.clamp(-threshold, threshold);
      delta.value = [boundary, current];
    }, []);

    useEffect(() {
      scrollController.addListener(onScrolling);
      return () {
        scrollController.removeListener(onScrolling);
      };
    }, []);

    // Reset delta when there's no scrollable widget attached.
    // for example: on new search or while switching server.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (scrollController.hasClients) return;
      if (delta.value.reduce((a, b) => a + b) != 0) {
        delta.value = [0, 0];
      }
    });

    return RepaintBoundary(
      child: BlurBackdrop(
        sigmaX: 8,
        sigmaY: 8,
        blur: isBlurAllowed,
        child: Container(
          color: context.theme.scaffoldBackgroundColor.withOpacity(
            context.isLightThemed
                ? isBlurAllowed
                    ? 0.7
                    : 0.92
                : isBlurAllowed
                    ? 0.85
                    : 0.97,
          ),
          child: SafeArea(
            top: false,
            maintainBottomViewPadding: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (searchBar.isOpen)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 11, 18, 0),
                    child: _OptionBar(),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(collapsed ? 0 : 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(15)),
                  ),
                  margin: collapsed
                      ? const EdgeInsets.fromLTRB(32, 4, 32, 0)
                      : const EdgeInsets.fromLTRB(16, 11, 16, 11),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          _LeadingButton(collapsed: collapsed),
                          if (!searchBar.isOpen)
                            Positioned(right: 8, child: _RatingIndicator()),
                        ],
                      ),
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          enableIMEPersonalizedLearning: !imeIncognito,
                          controller: searchBar.textEditingController,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: searchBar.value.isEmpty
                                ? context.t.searchHint(serverName: server.name)
                                : searchBar.value,
                            isDense: true,
                          ),
                          textAlign: searchBar.isOpen
                              ? TextAlign.start
                              : TextAlign.center,
                          readOnly: !searchBar.isOpen,
                          onSubmitted: (str) {
                            searchBar.submit(context, str);
                          },
                          onTap: searchBar.isOpen ? null : searchBar.open,
                          style: DefaultTextStyle.of(context)
                              .style
                              .copyWith(fontSize: 13),
                        ),
                      ),
                      if (!searchBar.isOpen)
                        _TrailingButton(
                          collapsed: collapsed,
                          scrollController: scrollController,
                        ),
                      if (searchBar.isOpen &&
                          searchBar.value != searchBar.initial)
                        IconButton(
                          icon: const Icon(Icons.rotate_left),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          onPressed: searchBar.reset,
                        ),
                      if (searchBar.isOpen)
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          onPressed: searchBar.clear,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double innerHeight = kBottomNavigationBarHeight + 12;
}

class _OptionBar extends ConsumerWidget {
  const _OptionBar();

  Future<BooruRating?> selectRating(BuildContext context, BooruRating current) {
    return showDialog<BooruRating>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.colorScheme.background,
          title: Text(context.t.rating.title),
          icon: const Icon(Icons.star),
          contentPadding: const EdgeInsets.only(top: 16, bottom: 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: BooruRating.values
                .map((e) => RadioListTile(
                      value: e,
                      groupValue: current,
                      title: Text(e.getString(context)),
                      onChanged: (x) {
                        context.navigator.pop(x);
                      },
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating =
        ref.watch(serverSettingStateProvider.select((it) => it.searchRating));

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () async {
            final selected = await selectRating(context, rating);
            if (selected != null) {
              await ref
                  .read(serverSettingStateProvider.notifier)
                  .setRating(selected);
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            minimumSize: const Size(1, 1),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side:
                BorderSide(width: 1, color: context.colorScheme.surfaceVariant),
            elevation: 0,
          ),
          child: Text(
            '${context.t.rating.title}: ${rating.getString(context)}'
                .toLowerCase(),
            style: TextStyle(color: context.colorScheme.onSurface),
          ),
        )
      ],
    );
  }
}

class _CollapsibleButton extends StatelessWidget {
  const _CollapsibleButton({
    this.collapsed = false,
    required this.onTap,
    this.child,
  });

  final bool collapsed;
  final void Function() onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 300),
        padding: collapsed
            ? const EdgeInsets.fromLTRB(16, 6, 16, 6)
            : const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: collapsed ? 0.75 : 1,
          child: child,
        ),
      ),
    );
  }
}

class _LeadingButton extends ConsumerWidget {
  const _LeadingButton({this.collapsed = false});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageArgs = ref.watch(homePageArgsProvider);
    final server =
        ref.watch(serverDataStateProvider).getById(pageArgs.serverId);
    final searchBar = ref.watch(searchBarControllerProvider);

    return _CollapsibleButton(
      collapsed: collapsed,
      onTap: () {
        if (searchBar.isOpen) {
          searchBar.close();
        } else {
          ref.read(homeDrawerControllerProvider).toggle();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animator) {
          final animation = Tween<double>(
            begin: 0,
            end: 1,
          ).animate(CurvedAnimation(
            parent: animator,
            curve: Curves.easeInOutCubic,
          ));
          return RotationTransition(
            turns: animation,
            child: ScaleTransition(
              scale: animation,
              child: child,
            ),
          );
        },
        child: searchBar.isOpen
            ? const Icon(Icons.arrow_back_rounded)
            : Favicon(
                key: ValueKey(server.homepage),
                url: server.homepage,
                iconSize: 18,
              ),
      ),
    );
  }
}

class _RatingIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating =
        ref.watch(serverSettingStateProvider.select((it) => it.searchRating));

    String letter = 's';
    switch (rating) {
      case BooruRating.questionable:
        letter = 'q';
        break;
      case BooruRating.explicit:
        letter = 'e';
        break;
      default:
        break;
    }
    Color color = Colors.green.shade800;
    switch (rating) {
      case BooruRating.questionable:
        color = Colors.grey.shade800;
        break;
      case BooruRating.explicit:
        color = Colors.red.shade800;
        break;
      default:
        break;
    }
    return Visibility(
      visible: rating != BooruRating.all,
      child: Container(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        padding: const EdgeInsets.all(4),
        child: Text(letter,
            style: const TextStyle(fontSize: 10, color: Colors.white)),
      ),
    );
  }
}

class _TrailingButton extends ConsumerWidget {
  const _TrailingButton({this.collapsed = false, this.scrollController});

  final bool collapsed;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = context.iconTheme.size ?? 24;
    final grid = ref.watch(uiSettingStateProvider.select((ui) => ui.grid));

    backToTop() {
      scrollController?.animateTo(0,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic);
    }

    return _CollapsibleButton(
      onTap: collapsed
          ? backToTop
          : ref.read(uiSettingStateProvider.notifier).cycleGrid,
      collapsed: collapsed,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animator) {
            final animation = Tween<double>(
              begin: 0,
              end: 1,
            ).animate(CurvedAnimation(
              parent: animator,
              curve: Curves.easeInOutCubic,
            ));
            return RotationTransition(
              turns: animation,
              child: ScaleTransition(
                scale: animation,
                child: child,
              ),
            );
          },
          child: collapsed
              ? const Icon(Icons.arrow_upward_rounded)
              : Icon(key: ValueKey(grid), Icons.grid_view, size: 20),
        ),
      ),
    );
  }
}
