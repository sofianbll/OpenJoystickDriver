# Spec Delta

## Purpose

Let users explicitly publish a Nintendo Switch Pro virtual controller while preserving existing output choices and distinguishing source-backed protocol behavior from observed compatibility.

## ADDED Requirements

### Requirement: Explicit Nintendo output selection

OJD SHALL offer `SwitchPro` through the app's virtual profile picker, CLI and endpoint. The CLI spelling SHALL be `switch-pro`. Automatic selection SHALL remain unchanged and SHALL NOT select SwitchPro without an explicit user choice.

#### Scenario: Select the Nintendo output

- **WHEN** a user selects `switch-pro` for a controller eligible for virtual output
- **THEN** its published identity is USB `057E:2009` with a Nintendo Pro Controller product name
- **AND** the choice persists through the existing override mechanism

#### Scenario: No explicit Nintendo choice

- **WHEN** a user has no profile override
- **THEN** OJD selects the same profile it selected without this capability

### Requirement: Core Switch Pro input

The Switch Pro output SHALL encode face buttons, shoulders, digital triggers, D-pad, both sticks, stick clicks, Plus, Minus, Home and Capture in Nintendo reports. Face buttons SHALL retain physical position, not Xbox letter names. Rest and release SHALL produce neutral controls.

#### Scenario: Nintendo face button positions

- **WHEN** normalized South, East, West or North is pressed alone
- **THEN** the Nintendo report sets B, A, Y or X respectively
- **AND** releasing the control clears its bit

#### Scenario: Sticks and triggers

- **WHEN** neutral, full deflection and digital trigger presses are encoded
- **THEN** sticks use calibrated Nintendo centers and bounded extremes
- **AND** ZL and ZR represent pressed or released rather than advertised analog pressure

#### Scenario: System buttons

- **WHEN** Home or Capture is pressed and released
- **THEN** the corresponding Nintendo report bit changes independently
- **AND** this byte-level result is not reported as proof that a consumer delivers the button

### Requirement: Nintendo host initialization

The virtual controller SHALL answer its supported USB initialization, device-information, input-mode and calibration requests with Nintendo-framed responses. Responses SHALL be ordered with input delivery and preserve the latest control state. Emulated calibration SHALL match the emitted stick range.

#### Scenario: Device information and calibration

- **WHEN** a host sends a supported, well-formed device-information or calibration request
- **THEN** it receives the matching report ID, acknowledgement, echoed command and bounded data
- **AND** calibration addresses refer only to emulated controller data

#### Scenario: A request arrives during a button hold

- **WHEN** a host initialization request arrives while a button is held
- **THEN** any reply that carries controller state preserves that hold
- **AND** the next release is delivered in order

### Requirement: Safe host requests

Malformed, oversized and unsupported host reports SHALL fail explicitly without an acknowledgement of unsupported behavior, out-of-bounds access, unbounded allocation or physical-device writes. Accepted no-op protocol controls SHALL have documented responses without claiming physical motion, haptics or LED support.

#### Scenario: Truncated SPI request

- **WHEN** a calibration request omits address or length bytes
- **THEN** it is rejected without publishing a reply or changing controller state

#### Scenario: Oversized or unknown request

- **WHEN** a host requests data beyond the permitted response size or sends an unsupported command
- **THEN** OJD returns the corresponding failure without silent success or fallback

### Requirement: Isolated device lifecycle

Protocol counters and mutable initialization state SHALL belong to one virtual controller. Closing a device SHALL stop its reports and reject subsequent requests. Protocol replies SHALL preserve the existing bounded delivery and button-edge guarantees.

#### Scenario: Two virtual controllers

- **WHEN** two Switch Pro virtual controllers receive interleaved requests
- **THEN** each maintains its own counter and state
- **AND** closing one does not reset or close the other

#### Scenario: Close during initialization

- **WHEN** a virtual controller closes with a reply queued
- **THEN** no report is published after backend teardown
- **AND** a later request fails as closed

### Requirement: Synthetic feed without a physical profile

The existing virtual feed SHALL accept the SwitchPro output and publish input from normalized frames without requiring a physical controller record. The feed SHALL retain its existing validation, access controls and cleanup behavior.

#### Scenario: Feed Nintendo input

- **WHEN** an authorized caller opens a `switch-pro` feed and supplies button and stick frames
- **THEN** the output has the Switch Pro identity and Nintendo report layout
- **AND** ending the feed removes its virtual controller through the existing cleanup path

### Requirement: No additional privileged component

The feature SHALL use OJD's existing authorized virtual HID publication path. It SHALL NOT install a broker, add a DEXT, widen signing entitlements or disable SIP or AMFI. Builds without required Apple authorization SHALL not be represented as runtime-validated virtual devices.

#### Scenario: Protocol tests without signing assets

- **WHEN** a contributor runs source-backed encoding and fake-backend tests
- **THEN** they run without Apple signing credentials or physical controller access
- **AND** their result makes no claim about system-wide device creation

### Requirement: Preserve attribution

Adapted permissively licensed protocol code and descriptor bytes SHALL retain their applicable copyright and permission notices. The contribution SHALL identify its pinned source revision and SHALL NOT incorporate the separately licensed libvirtualhid broker.

#### Scenario: Review reused protocol material

- **WHEN** a reviewer inspects the adapted implementation
- **THEN** the source/license record names the original paths and revision
- **AND** the applicable MIT notices accompany substantial adapted portions

### Requirement: Honest compatibility status

Documentation SHALL distinguish source fixtures, HID enumeration, Steam/SDL behavior, GameController enumeration and live input. PowerA support, Home/Capture delivery, motion, physical feedback and battery telemetry SHALL remain not verified unless supported by their own observed tests.

#### Scenario: Source tests pass without a signed runtime test

- **WHEN** all offline tests pass but no signed-build consumer test has run
- **THEN** the profile is described as implemented with consumer compatibility not verified
- **AND** `supportsHIDDevice = true` alone does not count as functional GameController input
