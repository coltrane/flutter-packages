// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import XCTest

@testable import camera_avfoundation

// Import Objectice-C part of the implementation when SwiftPM is used.
#if canImport(camera_avfoundation_objc)
  import camera_avfoundation_objc
#endif

final class AvailableCamerasTest: XCTestCase {
  private func createCameraPlugin(with deviceDiscoverer: MockCameraDeviceDiscoverer) -> CameraPlugin
  {
    return CameraPlugin(
      registry: MockFlutterTextureRegistry(),
      messenger: MockFlutterBinaryMessenger(),
      globalAPI: MockGlobalEventApi(),
      deviceDiscoverer: deviceDiscoverer,
      permissionManager: MockFLTCameraPermissionManager(),
      deviceFactory: { _ in MockCaptureDevice() },
      captureSessionFactory: { MockCaptureSession() },
      captureDeviceInputFactory: MockCaptureDeviceInputFactory(),
      captureSessionQueue: DispatchQueue(label: "io.flutter.camera.captureSessionQueue")
    )
  }

  private func createCameraDeviceList() -> [MockCaptureDevice] {
    var cameras: [MockCaptureDevice] = []

    // all known built-in iPhone cameras as of August 2025
    let wideAngleCamera = MockCaptureDevice()
    wideAngleCamera.uniqueID = "0"
    wideAngleCamera.position = .back
    wideAngleCamera.deviceType = .builtInWideAngleCamera

    let frontFacingCamera = MockCaptureDevice()
    frontFacingCamera.uniqueID = "1"
    frontFacingCamera.position = .front
    frontFacingCamera.deviceType = .builtInWideAngleCamera

    let telephotoCamera = MockCaptureDevice()
    telephotoCamera.uniqueID = "2"
    telephotoCamera.position = .back
    telephotoCamera.deviceType = .builtInTelephotoCamera

    let dualCamera = MockCaptureDevice()
    dualCamera.uniqueID = "3"
    dualCamera.position = .back
    dualCamera.deviceType = .builtInDualCamera

    if #available(iOS 13.0, *) {
      let ultraWideCamera = MockCaptureDevice()
      ultraWideCamera.uniqueID = "5"
      ultraWideCamera.position = .back
      ultraWideCamera.deviceType = .builtInUltraWideCamera

      let dualWideCamera = MockCaptureDevice()
      dualWideCamera.uniqueID = "6"
      dualWideCamera.position = .back
      dualWideCamera.deviceType = .builtInDualWideCamera

      let tripleCamera = MockCaptureDevice()
      tripleCamera.uniqueID = "7"
      tripleCamera.position = .back
      tripleCamera.deviceType = .builtInTripleCamera

      // the order of `cameras` is important. It must match the order of the
      // discoveryDevices list used by availableCameras()
      cameras = [
        tripleCamera, dualWideCamera, dualCamera, wideAngleCamera, frontFacingCamera,
        ultraWideCamera, telephotoCamera,
      ]
    } else {
      cameras = [dualCamera, wideAngleCamera, frontFacingCamera, telephotoCamera]
    }
    
    return cameras;
  }

  func testAvailableCamerasShouldReturnAllCamerasOnMultiCameraIPhone() {
    let mockDeviceDiscoverer = MockCameraDeviceDiscoverer()
    let cameraPlugin = createCameraPlugin(with: mockDeviceDiscoverer)
    let expectation = self.expectation(description: "Result finished")

    let cameras = createCameraDeviceList()

    // The order of expectedDeviceTypes is important. We will be checking that
    // availableCameras() requests the correct DeviceTypes in the correct order.
    var expectedDeviceTypes: [AVCaptureDevice.DeviceType] = []
    if #available(iOS 13.0, *) {
      expectedDeviceTypes.append(.builtInTripleCamera)
      expectedDeviceTypes.append(.builtInDualWideCamera)
    }
    expectedDeviceTypes.append(.builtInDualCamera)
    expectedDeviceTypes.append(.builtInWideAngleCamera)
    if #available(iOS 13.0, *) {
      expectedDeviceTypes.append(.builtInUltraWideCamera)
    }
    expectedDeviceTypes.append(.builtInTelephotoCamera)

    mockDeviceDiscoverer.discoverySessionStub = { deviceTypes, mediaType, position in
      XCTAssertEqual(deviceTypes, expectedDeviceTypes)
      XCTAssertEqual(mediaType, .video)
      XCTAssertEqual(position, .unspecified)
      
      return cameras
    }

    var resultValue: [FCPPlatformCameraDescription]?
    cameraPlugin.availableCameras { result, error in
      XCTAssertNil(error)
      resultValue = result
      expectation.fulfill()
    }
    waitForExpectations(timeout: 30, handler: nil)

    // Verify the result.
    XCTAssertEqual(resultValue?.count, cameras.count)
  }

  func testAvailableCamerasShouldReturnTwoCamerasOnDualCameraIPhone() {
    let mockDeviceDiscoverer = MockCameraDeviceDiscoverer()
    let cameraPlugin = createCameraPlugin(with: mockDeviceDiscoverer)
    let expectation = self.expectation(description: "Result finished")

    mockDeviceDiscoverer.discoverySessionStub = { deviceTypes, mediaType, position in
      // iPhone 8 Cameras:
      let wideAngleCamera = MockCaptureDevice()
      wideAngleCamera.uniqueID = "0"
      wideAngleCamera.position = .back

      let frontFacingCamera = MockCaptureDevice()
      frontFacingCamera.uniqueID = "1"
      frontFacingCamera.position = .front

      let cameras = [wideAngleCamera, frontFacingCamera]
      
      return cameras
    }

    var resultValue: [FCPPlatformCameraDescription]?
    cameraPlugin.availableCameras { result, error in
      XCTAssertNil(error)
      resultValue = result
      expectation.fulfill()
    }
    waitForExpectations(timeout: 30, handler: nil)

    // Verify the result.
    XCTAssertEqual(resultValue?.count, 2)
  }

  func testAvailableCamerasShouldReturnExternalLensDirectionForUnspecifiedCameraPosition() {
    let mockDeviceDiscoverer = MockCameraDeviceDiscoverer()
    let cameraPlugin = createCameraPlugin(with: mockDeviceDiscoverer)
    let expectation = self.expectation(description: "Result finished")

    mockDeviceDiscoverer.discoverySessionStub = { deviceTypes, mediaType, position in
      let unspecifiedCamera = MockCaptureDevice()
      unspecifiedCamera.uniqueID = "0"
      unspecifiedCamera.position = .unspecified

      let cameras = [unspecifiedCamera]
      
      return cameras
    }

    var resultValue: [FCPPlatformCameraDescription]?
    cameraPlugin.availableCameras { result, error in
      XCTAssertNil(error)
      resultValue = result
      expectation.fulfill()
    }
    waitForExpectations(timeout: 30, handler: nil)

    XCTAssertEqual(resultValue?.first?.lensDirection, .external)
  }
}
