#!/usr/bin/env node

/**
 * WebRTC Test Client - Simulates a Rider for Testing
 * 
 * This script connects to your backend and simulates a rider
 * that can receive and answer calls from the customer app.
 * 
 * Usage:
 *   node webrtc-test-client.js
 */

const io = require('socket.io-client');
const readline = require('readline');
const wrtc = require('wrtc');

// Configuration
const BACKEND_URL = 'https://grabgo-backend.onrender.com';
const RIDER_ID = 'test-rider-123';
const RIDER_TOKEN = 'YOUR_RIDER_JWT_TOKEN'; // Replace with actual token

// Colors for console output
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
    red: '\x1b[31m',
};

class WebRTCTestClient {
    constructor() {
        this.socket = null;
        this.peerConnection = null;
        this.currentCallId = null;
        this.localStream = null;
        this.remoteStream = null;
        this.rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout,
        });
    }

    log(message, color = colors.reset) {
        console.log(`${color}${message}${colors.reset}`);
    }

    async connect() {
        this.log('\n🚀 Starting WebRTC Test Client...', colors.bright);
        this.log(`📡 Connecting to: ${BACKEND_URL}`, colors.cyan);

        this.socket = io(BACKEND_URL, {
            transports: ['websocket'],
            auth: {
                token: RIDER_TOKEN,
            },
        });

        this.setupSocketListeners();
    }

    setupSocketListeners() {
        this.socket.on('connect', () => {
            this.log('✅ Connected to backend!', colors.green);
            this.log(`👤 Registering as rider: ${RIDER_ID}`, colors.cyan);
            this.socket.emit('webrtc:register', RIDER_ID);
            this.showMenu();
        });

        this.socket.on('disconnect', () => {
            this.log('❌ Disconnected from backend', colors.red);
        });

        this.socket.on('connect_error', (error) => {
            this.log(`❌ Connection error: ${error.message}`, colors.red);
        });

        // WebRTC Events
        this.socket.on('webrtc:incoming-call', (data) => this.handleIncomingCall(data));
        this.socket.on('webrtc:call-answered', (data) => this.handleCallAnswered(data));
        this.socket.on('webrtc:ice-candidate', (data) => this.handleIceCandidate(data));
        this.socket.on('webrtc:call-ended', (data) => this.handleCallEnded(data));
        this.socket.on('webrtc:call-rejected', (data) => this.handleCallRejected(data));
        this.socket.on('webrtc:error', (data) => this.handleError(data));
    }

    async handleIncomingCall(data) {
        this.log('\n📞 INCOMING CALL!', colors.bright + colors.green);
        this.log(`   Caller: ${data.callerId}`, colors.cyan);
        this.log(`   Order: ${data.orderId}`, colors.cyan);
        this.log(`   Call ID: ${data.callId}`, colors.cyan);

        this.currentCallId = data.callId;

        this.rl.question('\n👉 Answer call? (y/n): ', async (answer) => {
            if (answer.toLowerCase() === 'y') {
                await this.answerCall(data);
            } else {
                this.rejectCall();
            }
        });
    }

    async answerCall(data) {
        try {
            this.log('\n📱 Answering call...', colors.yellow);

            // Create peer connection
            await this.createPeerConnection();

            // Create fake audio stream (silent)
            this.localStream = this.createFakeAudioStream();
            this.localStream.getTracks().forEach((track) => {
                this.peerConnection.addTrack(track, this.localStream);
            });

            // Set remote description (offer)
            await this.peerConnection.setRemoteDescription(
                new wrtc.RTCSessionDescription(data.offer)
            );

            // Create answer
            const answer = await this.peerConnection.createAnswer();
            await this.peerConnection.setLocalDescription(answer);

            // Send answer to backend
            this.socket.emit('webrtc:answer', {
                callId: this.currentCallId,
                answer: {
                    sdp: answer.sdp,
                    type: answer.type,
                },
            });

            this.log('✅ Call answered!', colors.green);
            this.log('🎙️  Call is now active (simulated audio)', colors.cyan);
            this.showCallMenu();
        } catch (error) {
            this.log(`❌ Error answering call: ${error.message}`, colors.red);
        }
    }

    rejectCall() {
        this.log('\n🚫 Rejecting call...', colors.yellow);
        this.socket.emit('webrtc:reject', {
            callId: this.currentCallId,
        });
        this.currentCallId = null;
        this.log('✅ Call rejected', colors.green);
        this.showMenu();
    }

    endCall() {
        this.log('\n📴 Ending call...', colors.yellow);
        this.socket.emit('webrtc:end-call', {
            callId: this.currentCallId,
        });
        this.cleanup();
        this.log('✅ Call ended', colors.green);
        this.showMenu();
    }

    async createPeerConnection() {
        const config = {
            iceServers: [
                { urls: 'stun:stun.l.google.com:19302' },
                {
                    urls: 'turn:34.136.2.17:3478',
                    username: 'testuser',
                    credential: 'testpass',
                },
            ],
        };

        this.peerConnection = new wrtc.RTCPeerConnection(config);

        // Handle ICE candidates
        this.peerConnection.onicecandidate = (event) => {
            if (event.candidate) {
                this.socket.emit('webrtc:ice-candidate', {
                    callId: this.currentCallId,
                    candidate: {
                        candidate: event.candidate.candidate,
                        sdpMid: event.candidate.sdpMid,
                        sdpMLineIndex: event.candidate.sdpMLineIndex,
                    },
                    targetUserId: 'customer',
                });
            }
        };

        // Handle remote stream
        this.peerConnection.ontrack = (event) => {
            this.log('🎵 Receiving remote audio stream', colors.cyan);
            this.remoteStream = event.streams[0];
        };

        // Handle connection state
        this.peerConnection.onconnectionstatechange = () => {
            this.log(`📡 Connection state: ${this.peerConnection.connectionState}`, colors.cyan);
            if (this.peerConnection.connectionState === 'connected') {
                this.log('✅ P2P connection established!', colors.green);
            }
        };
    }

    async handleCallAnswered(data) {
        this.log('\n✅ Call answered by customer!', colors.green);
        await this.peerConnection.setRemoteDescription(
            new wrtc.RTCSessionDescription(data.answer)
        );
    }

    async handleIceCandidate(data) {
        if (this.peerConnection) {
            await this.peerConnection.addCandidate(
                new wrtc.RTCIceCandidate(data.candidate)
            );
            this.log('🧊 ICE candidate added', colors.cyan);
        }
    }

    handleCallEnded(data) {
        this.log('\n📴 Call ended by customer', colors.yellow);
        this.cleanup();
        this.showMenu();
    }

    handleCallRejected(data) {
        this.log('\n🚫 Call rejected by customer', colors.yellow);
        this.cleanup();
        this.showMenu();
    }

    handleError(data) {
        this.log(`\n❌ WebRTC Error: ${data.error}`, colors.red);
    }

    createFakeAudioStream() {
        // Create a silent audio track for testing
        const audioContext = new wrtc.nonstandard.RTCAudioSource();
        const track = audioContext.createTrack();
        return new wrtc.MediaStream([track]);
    }

    cleanup() {
        if (this.localStream) {
            this.localStream.getTracks().forEach((track) => track.stop());
            this.localStream = null;
        }
        if (this.peerConnection) {
            this.peerConnection.close();
            this.peerConnection = null;
        }
        this.currentCallId = null;
    }

    showMenu() {
        this.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', colors.bright);
        this.log('📱 WebRTC Test Client - Main Menu', colors.bright);
        this.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', colors.bright);
        this.log('   Status: Waiting for incoming calls...', colors.green);
        this.log('   Rider ID: ' + RIDER_ID, colors.cyan);
        this.log('\n   Commands:', colors.yellow);
        this.log('   - Press Ctrl+C to exit', colors.cyan);
        this.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n', colors.bright);
    }

    showCallMenu() {
        this.rl.question('\n👉 Type "end" to end call: ', (answer) => {
            if (answer.toLowerCase() === 'end') {
                this.endCall();
            } else {
                this.showCallMenu();
            }
        });
    }

    start() {
        this.connect();

        // Handle Ctrl+C
        process.on('SIGINT', () => {
            this.log('\n\n👋 Shutting down...', colors.yellow);
            this.cleanup();
            if (this.socket) {
                this.socket.disconnect();
            }
            this.rl.close();
            process.exit(0);
        });
    }
}

// Start the test client
const client = new WebRTCTestClient();
client.start();
