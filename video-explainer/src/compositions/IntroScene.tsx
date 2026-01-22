import {AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, spring} from 'remotion';

export const IntroScene: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();

	// Logo fade in animation
	const logoOpacity = interpolate(frame, [0, 30], [0, 1], {
		extrapolateRight: 'clamp',
	});

	// Logo scale animation using spring
	const logoScale = spring({
		frame,
		fps,
		config: {
			damping: 200,
		},
	});

	// Text slide up animation
	const textY = interpolate(frame, [60, 90], [100, 0], {
		extrapolateRight: 'clamp',
	});

	const textOpacity = interpolate(frame, [60, 90], [0, 1], {
		extrapolateRight: 'clamp',
	});

	return (
		<AbsoluteFill
			style={{
				backgroundColor: '#0a0a0a',
				justifyContent: 'center',
				alignItems: 'center',
			}}
		>
			{/* Logo */}
			<div
				style={{
					opacity: logoOpacity,
					transform: `scale(${logoScale})`,
				}}
			>
				<div
					style={{
						fontSize: 120,
						fontWeight: 'bold',
						background: 'linear-gradient(135deg, #9333ea 0%, #3b82f6 100%)',
						WebkitBackgroundClip: 'text',
						WebkitTextFillColor: 'transparent',
						fontFamily: 'monospace',
					}}
				>
					feature-marker
				</div>
			</div>

			{/* Subtitle */}
			<div
				style={{
					position: 'absolute',
					bottom: '30%',
					opacity: textOpacity,
					transform: `translateY(${textY}px)`,
					textAlign: 'center',
				}}
			>
				<div
					style={{
						fontSize: 48,
						color: '#ffffff',
						marginBottom: 20,
						fontWeight: 600,
					}}
				>
					Automate your feature development workflow
				</div>
				<div
					style={{
						fontSize: 32,
						color: '#9ca3af',
					}}
				>
					with AI-powered checkpoints
				</div>
			</div>
		</AbsoluteFill>
	);
};
