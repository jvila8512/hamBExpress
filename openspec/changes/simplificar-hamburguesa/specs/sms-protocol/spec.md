# Delta for SMS Protocol

## REMOVED Requirements

This capability is REMOVED IN ITS ENTIRETY. `openspec/specs/sms-protocol/spec.md` SHALL be deleted when this change is archived. Structured SMS between role devices is replaced by a plain `sms:` intent launched from the order row (specified in `order-management` → *Order Row Actions*): the app opens the composer and the user taps send; nothing is parsed, deduplicated, or auto-acknowledged.

### Requirement: Payload Types

(Reason: the `PED`/`ACK`/`HEC`/`ENT`/`CAN` payload types exist only to move state between Redes/Cocina/Domicilio devices. Those roles and that transport are deleted; state changes are local user actions.)

### Requirement: JSON Minified Format

(Reason: there is no machine-to-machine SMS payload anymore, so there is no 160-character envelope to serialize into.)

### Requirement: Background SMS Reception

(Reason: the `telephony` `BroadcastReceiver`, JSON parsing of incoming SMS, and the discard-on-unparseable rule are deleted. The app never reads incoming SMS.)

### Requirement: Deduplication by Order ID

(Reason: with no incoming payload there is nothing to deduplicate; orders are created once by a local user action.)

### Requirement: Pipe-Delimited Fallback

(Reason: no incoming parser exists, so the fallback format and its auto-detection are deleted.)
