import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/spec_2026_models.dart';

/// Admin-only `Announcements` workspace — create, edit, pin, and delete campus
/// bulletins targeted to student, faculty, and staff audiences.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  String? _banner;

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final profile = ref.watch(authControllerProvider).profile;
    final isAdmin = profile?.role.isAdmin ?? false;
    if (!isAdmin || profile == null) {
      return const ScreenScaffold(
        children: [
          PageIntro(
            title: 'Announcements',
            subtitle: 'Campus parking notices for mobile app users.',
          ),
          SizedBox(height: 18),
          RoleRestrictedPanel(
            featureName: 'Campus Announcements Management',
            minimumRole: 'administrator',
          ),
        ],
      );
    }

    final ops = ref.watch(desktopOpsControllerProvider);

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Announcements',
          subtitle:
              'Publish maintenance notices, lot closures, and priority rules for students, faculty, and staff.',
          actions: [
            FilledButton.icon(
              key: const Key('announcement_new_btn'),
              onPressed: () => _openEditorDialog(context, actor: profile),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('New Announcement'),
            ),
          ],
        ),
        if (_banner != null) ...[
          const SizedBox(height: 14),
          Callout(
            tone: PillTone.ok,
            icon: Icons.check_circle_outline_rounded,
            title: 'Announcements updated',
            message: _banner!,
          ),
        ],
        const SizedBox(height: 18),
        if (ops.announcements.isEmpty)
          const SentryCard(
            child: EmptyState(
              icon: Icons.campaign_outlined,
              title: 'No announcements posted',
              message: 'Click New Announcement to notify campus drivers.',
            ),
          )
        else
          for (final ann in ops.announcements) ...[
            SentryCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            ann.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (ann.pinned)
                            const StatusPill(
                              label: 'Pinned',
                              tone: PillTone.crimson,
                              icon: Icons.push_pin_outlined,
                            ),
                          for (final role in ann.audienceRoles)
                            StatusPill(
                              label: role,
                              tone: PillTone.info,
                              monospace: true,
                            ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            key: Key('announcement_edit_${ann.announcementId}'),
                            onPressed: () => _openEditorDialog(
                              context,
                              actor: profile,
                              existing: ann,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit'),
                          ),
                          OutlinedButton.icon(
                            key: Key(
                                'announcement_delete_${ann.announcementId}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SentryColors.crimson,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(desktopOpsControllerProvider.notifier)
                                  .deleteAnnouncement(
                                    ann.announcementId,
                                    actor: profile,
                                  );
                              if (!mounted) return;
                              setState(() {
                                _banner = 'Deleted "${ann.title}".';
                              });
                            },
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(ann.body, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Posted by ${ann.authorUserCode} · ${ManilaTime.formatDateTime(ann.publishedAtUtc)}',
                    style: SentryTheme.mono(fontSize: 12, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Future<void> _openEditorDialog(
    BuildContext context, {
    required ProfileDto actor,
    AnnouncementDto? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    bool pinned = existing?.pinned ?? false;
    final selectedRoles = Set<String>.from(
      existing?.audienceRoles ?? const ['student', 'faculty', 'staff'],
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final valid =
              titleCtrl.text.trim().isNotEmpty && bodyCtrl.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(
              existing == null ? 'New Announcement' : 'Edit Announcement',
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('announcement_title_field'),
                    controller: titleCtrl,
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('announcement_body_field'),
                    controller: bodyCtrl,
                    minLines: 3,
                    maxLines: 5,
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(labelText: 'Message *'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in const ['student', 'faculty', 'staff'])
                        FilterChip(
                          label: Text(r),
                          selected: selectedRoles.contains(r),
                          onSelected: (on) {
                            setModalState(() {
                              if (on) {
                                selectedRoles.add(r);
                              } else if (selectedRoles.length > 1) {
                                selectedRoles.remove(r);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pin to top of mobile noticeboard'),
                    value: pinned,
                    onChanged: (v) => setModalState(() => pinned = v),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('announcement_save_btn'),
                onPressed: valid ? () => Navigator.of(ctx).pop(true) : null,
                child: const Text('Publish'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(desktopOpsControllerProvider.notifier).saveAnnouncement(
            existing: existing,
            title: titleCtrl.text,
            body: bodyCtrl.text,
            audienceRoles: selectedRoles.toList(),
            pinned: pinned,
            actor: actor,
          );
      if (!mounted) return;
      setState(() {
        _banner =
            '${existing == null ? 'Published' : 'Updated'} "${titleCtrl.text.trim()}".';
      });
    }
  }
}
