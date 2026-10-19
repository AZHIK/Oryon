import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_dtos.dart';
import '../../constants/app_strings.dart';
import '../../models/business_profile.dart';
import '../../providers/business_api_provider.dart';
import '../../providers/settings_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/brand_palette.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/detail_page/detail_page_scaffold.dart';
import '../../widgets/field_pair.dart';
import '../../widgets/image_upload_field.dart';
import '../../widgets/labeled_form_field.dart';

/// Widget keys for the profile form's controls.
abstract final class BusinessProfileKeys {
  static const name = Key('businessProfile.name');
  static const type = Key('businessProfile.type');
  static const email = Key('businessProfile.email');
  static const phone = Key('businessProfile.phone');
  static const address = Key('businessProfile.address');
  static const city = Key('businessProfile.city');
  static const taxId = Key('businessProfile.taxId');
  static const registrationNumber = Key('businessProfile.registrationNumber');
  static const cuisineType = Key('businessProfile.cuisineType');
  static const licenseDocumentUrl = Key('businessProfile.licenseDocumentUrl');
  static const brandColor = Key('businessProfile.brandColor');
  static const receiptFooter = Key('businessProfile.receiptFooter');
  static const save = Key('businessProfile.save');
}

/// Edits business identity: name, type, and contact details synced with backend.
class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() =>
      _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _taxId = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _cuisineType = TextEditingController();
  final _licenseDocumentUrl = TextEditingController();

  late BusinessType _type;
  bool _seeded = false;
  bool _saving = false;
  bool _dirty = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;

    final profile = ref.read(businessProfileProvider);
    if (profile != null) {
      _name.text = profile.name;
      _email.text = profile.email ?? '';
      _phone.text = profile.phone ?? '';
      _address.text = profile.address ?? '';
      _city.text = profile.city ?? '';
      _taxId.text = profile.taxId ?? '';
      _registrationNumber.text = profile.registrationNumber ?? '';
      _cuisineType.text = profile.cuisineType ?? '';
      _licenseDocumentUrl.text = profile.licenseDocumentUrl ?? '';
      _type = profile.businessType;
    } else {
      _type = BusinessType.restaurant;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _address,
      _city,
      _taxId,
      _registrationNumber,
      _cuisineType,
      _licenseDocumentUrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    final profile = ref.read(businessProfileProvider);

    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.noProfileLoaded)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final input = BusinessUpdateInput(
        name: _name.text.trim(),
        businessType: _type.backendValue,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        taxId: _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
        registrationNumber:
            _registrationNumber.text.trim().isEmpty ? null : _registrationNumber.text.trim(),
        cuisineType: _cuisineType.text.trim().isEmpty ? null : _cuisineType.text.trim(),
        licenseDocumentUrl: _licenseDocumentUrl.text.trim().isEmpty
            ? null
            : _licenseDocumentUrl.text.trim(),
      );
      await ref.read(businessProfileNotifierProvider).update(profile.id, input);

      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.businessProfileSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.profileSaveFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(businessProfileProvider);

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: _touch,
      child: DetailPageScaffold(
        maxContentWidth: 1080,
        header: DetailPageHeader(
          title: AppStrings.businessProfileTitle,
          subtitle: AppStrings.businessProfileSubtitle,
          onBack: () => context.canPop()
              ? context.pop()
              : context.goNamed(AppRoute.settingsName),
          actions: [
            FilledButton.icon(
              key: BusinessProfileKeys.save,
              onPressed: (!_dirty || _saving) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                _saving ? AppStrings.savingEllipsis : AppStrings.saveChanges,
              ),
            ),
          ],
        ),
        sidePanel: [
          _BrandingPanel(
            profile: profile,
            onLogoPicked: (fileName, bytes) => _touch(),
            onLogoRemoved: () => _touch(),
            onColorPicked: (color) => _touch(),
          )
        ],
        children: [
          _DetailsPanel(
            profile: profile,
            name: _name,
            email: _email,
            phone: _phone,
            address: _address,
            city: _city,
            taxId: _taxId,
            registrationNumber: _registrationNumber,
            cuisineType: _cuisineType,
            licenseDocumentUrl: _licenseDocumentUrl,
            type: _type,
            onTypeChanged: (value) {
              setState(() {
                _type = value;
                _dirty = true;
              });
            },
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panels
// ---------------------------------------------------------------------------

/// Logo and accent colour — the two things that decide what a printed receipt
/// looks like before a word of it is read.
class _BrandingPanel extends StatelessWidget {
  const _BrandingPanel({
    required this.profile,
    required this.onLogoPicked,
    required this.onLogoRemoved,
    required this.onColorPicked,
  });

  final BusinessProfile profile;
  final void Function(String name, Uint8List bytes) onLogoPicked;
  final VoidCallback onLogoRemoved;
  final ValueChanged<Color> onColorPicked;

  @override
  Widget build(BuildContext context) {
    final compact = context.isMobile;
    final logoSize = compact ? 100.0 : 140.0;

    return DetailPanel(
      title: AppStrings.brandingPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: compact ? Alignment.center : Alignment.centerLeft,
            child: ImageUploadField(
              image: profile.logoBytes,
              size: logoSize,
              label: AppStrings.addLogoAction,
              hint: AppStrings.logoPreviewHint,
              onPicked: onLogoPicked,
              onRemoved: onLogoRemoved,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            AppStrings.logoReceiptHint,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.xl),
          _BrandColorPicker(
            selected: profile.brandColor,
            onPicked: onColorPicked,
          ),
        ],
      ),
    );
  }
}

/// A row of preset swatches plus a custom entry.
///
/// Presets rather than a full colour wheel because the eight here are hues the
/// rest of the app already pairs well with; the custom option exists for the
/// venue whose brand book says otherwise.
class _BrandColorPicker extends StatelessWidget {
  const _BrandColorPicker({required this.selected, required this.onPicked});

  final Color selected;
  final ValueChanged<Color> onPicked;

  static const double _swatchSize = 34;

  @override
  Widget build(BuildContext context) {
    final custom = BrandPalette.match(selected) == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.accentColour,
          style: context.text.labelLarge?.copyWith(
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: Insets.sm),
        Wrap(
          key: BusinessProfileKeys.brandColor,
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: [
            for (final swatch in BrandPalette.swatches)
              _Swatch(
                color: swatch.color,
                tooltip: swatch.name,
                selected:
                    swatch.color.toARGB32() == selected.toARGB32(),
                onTap: () => onPicked(swatch.color),
              ),
            _CustomSwatch(
              selected: custom,
              color: selected,
              onPicked: onPicked,
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _BrandPreviewStrip(color: selected),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        selected: selected,
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            height: _BrandColorPicker._swatchSize,
            width: _BrandColorPicker._swatchSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              // Selection is a ring around the swatch rather than a tint of
              // it: the swatch's own colour is the thing being chosen, so
              // nothing may alter it.
              border: Border.all(
                color: selected
                    ? context.colors.onSurface
                    : context.semantic.hairline,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Opens a small palette of extra hues.
///
/// A real colour wheel is a dependency this build does not carry, so "custom"
/// offers a second tier of choices rather than pretending to be an eyedropper.
class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({
    required this.selected,
    required this.color,
    required this.onPicked,
  });

  final bool selected;
  final Color color;
  final ValueChanged<Color> onPicked;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected ? 'Custom · ${BrandPalette.hex(color)}' : 'Custom',
      child: PopupMenuButton<Color>(
        onSelected: onPicked,
        tooltip: '',
        itemBuilder: (menuContext) => [
          for (final extra in BrandPalette.extras)
            PopupMenuItem(
              value: extra.color,
              child: Row(
                children: [
                  Container(
                    height: 18,
                    width: 18,
                    decoration: BoxDecoration(
                      color: extra.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Text(extra.name),
                ],
              ),
            ),
        ],
        child: Container(
          height: _BrandColorPicker._swatchSize,
          width: _BrandColorPicker._swatchSize,
          decoration: BoxDecoration(
            color: selected ? color : context.colors.surfaceContainerHigh,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? context.colors.onSurface
                  : context.semantic.hairline,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Icon(
            Icons.add_rounded,
            size: 17,
            color: selected ? Colors.white : context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Shows the chosen accent at the three weights a receipt actually uses it at,
/// so a colour that looks fine as a dot but muddy as a fill is caught here.
class _BrandPreviewStrip extends StatelessWidget {
  const _BrandPreviewStrip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            Expanded(child: ColoredBox(color: color)),
            Expanded(
              child: ColoredBox(color: color.withValues(alpha: 0.55)),
            ),
            Expanded(
              child: ColoredBox(color: color.withValues(alpha: 0.16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.profile,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.taxId,
    required this.registrationNumber,
    required this.cuisineType,
    required this.licenseDocumentUrl,
    required this.type,
    required this.onTypeChanged,
  });

  final BusinessProfile profile;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController address;
  final TextEditingController city;
  final TextEditingController taxId;
  final TextEditingController registrationNumber;
  final TextEditingController cuisineType;
  final TextEditingController licenseDocumentUrl;
  final BusinessType type;
  final ValueChanged<BusinessType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DetailPanel(
          title: AppStrings.businessDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              LabeledFormField(
                label: AppStrings.businessNameField,
                isRequired: true,
                helper: AppStrings.businessNameHelper,
                child: TextFormField(
                  key: BusinessProfileKeys.name,
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: AppStrings.businessNameHint2,
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? AppStrings.businessNameRequired
                      : null,
                ),
              ),
              const SizedBox(height: Insets.lg),
              FieldPair(
                left: LabeledFormField(
                  label: AppStrings.businessTypeField,
                  child: DropdownButtonFormField<BusinessType>(
                    key: BusinessProfileKeys.type,
                    initialValue: type,
                    isExpanded: true,
                    items: [
                      for (final option in BusinessType.values)
                        DropdownMenuItem(
                          value: option,
                          child: Row(
                            children: [
                              Icon(option.icon, size: 17),
                              const SizedBox(width: Insets.sm),
                              Flexible(
                                child: Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) onTypeChanged(value);
                    },
                  ),
                ),
                right: LabeledFormField(
                  label: AppStrings.cuisineField,
                  helper: AppStrings.optionalField,
                  child: TextFormField(
                    key: BusinessProfileKeys.cuisineType,
                    controller: cuisineType,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'e.g., Italian, Thai'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        DetailPanel(
          title: AppStrings.registrationPanel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              FieldPair(
                left: LabeledFormField(
                  label: AppStrings.taxIdField,
                  helper: AppStrings.taxIdHelper2,
                  child: TextFormField(
                    key: BusinessProfileKeys.taxId,
                    controller: taxId,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: AppStrings.optionalField,
                    ),
                  ),
                ),
                right: LabeledFormField(
                  label: AppStrings.registrationField,
                  helper: AppStrings.registrationHelper,
                  child: TextFormField(
                    key: BusinessProfileKeys.registrationNumber,
                    controller: registrationNumber,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: AppStrings.optionalField,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              LabeledFormField(
                label: AppStrings.licenseDocField,
                helper: AppStrings.licenseDocHelper2,
                child: TextFormField(
                  key: BusinessProfileKeys.licenseDocumentUrl,
                  controller: licenseDocumentUrl,
                  keyboardType: TextInputType.url,
                  decoration:
                      InputDecoration(hintText: AppStrings.urlExample),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        DetailPanel(
          title: AppStrings.contactPanel2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              FieldPair(
                left: LabeledFormField(
                  label: AppStrings.emailField2,
                  helper: AppStrings.emailHelper2,
                  child: TextFormField(
                    key: BusinessProfileKeys.email,
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: AppStrings.emailHint2,
                    ),
                  ),
                ),
                right: LabeledFormField(
                  label: AppStrings.phoneField2,
                  helper: AppStrings.phoneHelper2,
                  child: TextFormField(
                    key: BusinessProfileKeys.phone,
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: AppStrings.phoneHint2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              LabeledFormField(
                label: AppStrings.addressField2,
                helper: AppStrings.addressHelper2,
                child: TextFormField(
                  key: BusinessProfileKeys.address,
                  controller: address,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: AppStrings.addressHint2,
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              LabeledFormField(
                label: AppStrings.cityField,
                helper: AppStrings.cityHelper,
                child: TextFormField(
                  key: BusinessProfileKeys.city,
                  controller: city,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: AppStrings.cityExample,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A live receipt header, so the effect of an address, accent or footer edit is
/// visible without printing one.
///
/// Reads the profile and the store's tax settings from their own providers
/// rather than taking them as arguments: this is the same pair of sources the
/// real receipt reads, so a preview that agrees with it here agrees with it on