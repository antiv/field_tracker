import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tracker_core/tracker_core.dart';

/// Preference keys of the surveyor's details. Typed once, exported in every
/// row of the census sheet.
const String kSurveyorNameKey = 'surveyor_name';
const String kSurveyorEmailKey = 'surveyor_email';
const String kSurveyorPhoneKey = 'surveyor_phone';

/// Name, email and phone of the person doing the census.
class UserDetailsForm extends StatefulWidget {
  const UserDetailsForm({super.key});

  @override
  State<UserDetailsForm> createState() => _UserDetailsFormState();
}

class _UserDetailsFormState extends State<UserDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    final prefs = DataService();
    _nameController.text = prefs.getString(kSurveyorNameKey) ?? '';
    _emailController.text = prefs.getString(kSurveyorEmailKey) ?? '';
    _phoneController.text = prefs.getString(kSurveyorPhoneKey) ?? '';
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final prefs = DataService();
    prefs.setString(kSurveyorNameKey, _nameController.text.trim());
    prefs.setString(kSurveyorEmailKey, _emailController.text.trim());
    prefs.setString(kSurveyorPhoneKey, _phoneController.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('user_details_form'),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'surveyor_name'.tr(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'please_enter_value'.tr()
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'surveyor_email'.tr(),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'surveyor_phone'.tr(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(40),
                ),
                child: Text('save'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
