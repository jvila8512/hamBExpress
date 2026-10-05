# Delta for Trusted Contacts

## REMOVED Requirements

This capability is REMOVED IN ITS ENTIRETY. `openspec/specs/trusted-contacts/spec.md` SHALL be deleted when this change is archived. The trusted-contacts whitelist existed only as the origin filter for incoming SMS; with no SMS reception there is no origin to filter. The `TrustedContacts` table and the contacts screen are dropped with it.

### Requirement: Contact CRUD per Role

(Reason: contacts are scoped per restaurant role (`redes`, `cocina`, `domicilio`, `mesero`) — those roles are deleted, and no role needs a whitelist.)

### Requirement: SMS Origin Filter

(Reason: there is no background SMS receiver; nothing filters incoming origins.)

### Requirement: Role-Appropriate Contact Types

(Reason: role-scoped contact registration depends on the deleted restaurant roles.)

### Requirement: Contact Validation

(Reason: Cuban-mobile validation exists only to protect the SMS routing whitelist. Client cell numbers are still captured on orders and clients, but this requirement covered trusted contacts only.)
