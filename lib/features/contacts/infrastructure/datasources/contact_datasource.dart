import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/contacts/domain/entities/trusted_contact.dart' as domain;

/// Drift datasource for trusted contacts.
///
/// Schema v16 dropped the `trusted_contacts` table: the whitelist existed
/// only as the origin filter for incoming SMS, and SMS reception is gone.
/// With no backing table every operation resolves to an empty result or a
/// no-op until the contacts feature is deleted with the rest of the removed
/// capabilities (the trusted-contacts spec removes it in its entirety).
class ContactDatasource {
  /// The database parameter is kept so the existing wiring keeps compiling
  /// until the feature is removed; the datasource no longer reads from it.
  ContactDatasource(AppDatabase db);

  Future<void> createContact(domain.TrustedContact contact) async {}

  Future<domain.TrustedContact?> getContactById(String id) async => null;

  Future<List<domain.TrustedContact>> getContacts({String? rol}) async =>
      const [];

  Future<List<String>> getActivePhonesForRole(String rol) async => const [];

  Future<void> updateContact(domain.TrustedContact contact) async {}

  Future<void> toggleContactActive(String id, bool active) async {}

  Future<void> deleteContact(String id) async {}
}
