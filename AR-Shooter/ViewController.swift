//
//  ViewController.swift
//  AR-Shooter
//
//  Created by Martin Saporiti on 01/07/2018.
//  Copyright © 2018 Martin Saporiti. All rights reserved.
//

import UIKit
import ARKit
import Each
enum BitMaskCategory : Int {
    case bullet = 2
    case target = 3
}

class ViewController: UIViewController, ARSCNViewDelegate,  SCNPhysicsContactDelegate{

    
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    
    let configuration = ARWorldTrackingConfiguration()
    var power : Float = 50
    var target : SCNNode?
    var score = 0
    
    // Instantiate the audio source
    let audioSource = SCNAudioSource(fileNamed: "jump.mp3")!
    var timer = Each(2).seconds

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints,
                                       ARSCNDebugOptions.showWorldOrigin]
        
        sceneView.autoenablesDefaultLighting = true
//        configuration.planeDetection = .horizontal
        self.sceneView.scene.physicsWorld.contactDelegate = self
        self.sceneView.delegate = self
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(sender:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        
        tapGestureRecognizer.cancelsTouchesInView = false
        sceneView.session.run(configuration)
        
        self.timer.perform{ () -> NextStep in
            self.createEgg()
            return .continue
        }
        
        
        // As an environmental sound layer, audio should play indefinitely
        audioSource.loops = false
        // Decode the audio from disk ahead of time to prevent a delay in playback
        audioSource.load()
    }
    
    
    func createEgg(){
//        guard let pointOfView = self.sceneView.pointOfView else {return}
        
//        let transform = pointOfView.transform
//        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
//        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
//
//        let position = location + orientation
        
        addEgg(x: Float(randomNumbers(firstNum: -1, secondNum: 1)), y:  Float(randomNumbers(firstNum: 0, secondNum: 3)), z: Float(randomNumbers(firstNum: -2, secondNum: -10)))
    }
    
    
    @IBAction func addTargets(_ sender: UIButton) {
        guard let pointOfView = self.sceneView.pointOfView else {return}
        
        let transform = pointOfView.transform
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        
        let position = location + orientation
        
        addEgg(x: position.x + 50, y: position.y, z: position.z - 40)
        addEgg(x: position.x, y: position.y, z: position.z - 40)
        addEgg(x: position.x - 50, y: position.y, z: position.z - 40)
    }
    
    
    func addEgg(x: Float, y: Float, z: Float){
        let eggScene = SCNScene(named: "media.scnassets/egg.scn")
        let eggNode = eggScene?.rootNode.childNode(withName: "egg", recursively: false)
        eggNode?.position = SCNVector3(x, y, z)
        eggNode?.physicsBody =  SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: eggNode!, options: nil))
        eggNode?.physicsBody?.categoryBitMask = BitMaskCategory.target.rawValue
        eggNode?.physicsBody?.contactTestBitMask = BitMaskCategory.bullet.rawValue

        
        sceneView.scene.rootNode.addChildNode(eggNode!)

    }
    
    @objc func handleTap(sender: UITapGestureRecognizer){
        guard let sceneView = sender.view as? ARSCNView else {return}
        guard let pointOfView = sceneView.pointOfView else {return}

        let transform = pointOfView.transform
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        
        let position = location + orientation
        
        let bullet = SCNNode(geometry: SCNSphere(radius: 0.1))
        bullet.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        bullet.position = position
        bullet.name = "bullet"
        
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: bullet, options: nil))
        bullet.physicsBody = body
        body.isAffectedByGravity = false
        
        bullet.physicsBody?.applyForce(SCNVector3(orientation.x * power, orientation.y * power, orientation.z * power), asImpulse: true)
        bullet.physicsBody?.categoryBitMask = BitMaskCategory.bullet.rawValue
        bullet.physicsBody?.contactTestBitMask = BitMaskCategory.target.rawValue
        bullet.runAction(SCNAction.sequence([SCNAction.wait(duration: 2.0), SCNAction.removeFromParentNode()]))
        
        sceneView.scene.rootNode.addChildNode(bullet)

    }

    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        
        if (nodeA.physicsBody?.categoryBitMask == BitMaskCategory.target.rawValue){
            self.target = nodeA
        } else if (nodeB.physicsBody?.categoryBitMask == BitMaskCategory.target.rawValue){
            self.target = nodeB
        }
        
        let confestti = SCNParticleSystem(named: "media.scnassets/confetti.scnp", inDirectory: nil)
        confestti?.loops = false
        confestti?.particleLifeSpan = 4
        confestti?.emitterShape = target?.geometry
        
        let confettiNode = SCNNode()
        confettiNode.addParticleSystem(confestti!)
        confettiNode.position = contact.contactPoint
        target?.removeFromParentNode()
        sceneView.scene.rootNode.addChildNode(confettiNode)
        self.score += 1
        
        confettiNode.addAudioPlayer(SCNAudioPlayer(source: audioSource))
        DispatchQueue.main.async {
            self.scoreLabel.text = "\(self.score)"
        }
    }
    

}

func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
}

func randomNumbers(firstNum: CGFloat, secondNum: CGFloat) -> CGFloat {
    return CGFloat(arc4random()) / CGFloat(UINT32_MAX) * abs(firstNum - secondNum) + min(firstNum, secondNum)
}

