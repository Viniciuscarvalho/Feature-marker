import {AbsoluteFill, useCurrentFrame, interpolate} from 'remotion';

export const OutroScene: React.FC = () => {
	const frame = useCurrentFrame();

	// GitHub URL fade in
	const urlOpacity = interpolate(frame, [0, 30], [0, 1], {
		extrapolateRight: 'clamp',
	});

	// CTA fade in
	const ctaOpacity = interpolate(frame, [60, 90], [0, 1], {
		extrapolateRight: 'clamp',
	});

	// CTA pulse effect
	const ctaPulse = Math.sin(frame * 0.1) * 0.1 + 1;

	return (
		<AbsoluteFill
			style={{
				backgroundColor: '#0a0a0a',
				justifyContent: 'center',
				alignItems: 'center',
			}}
		>
			<div style={{textAlign: 'center'}}>
				{/* GitHub URL */}
				<div
					style={{
						opacity: urlOpacity,
						fontSize: 48,
						color: '#9333ea',
						fontFamily: 'monospace',
						marginBottom: 80,
					}}
				>
					github.com/Viniciuscarvalho/Feature-marker
				</div>

				{/* CTA */}
				<div
					style={{
						opacity: ctaOpacity,
						transform: `scale(${ctaPulse})`,
					}}
				>
					<div
						style={{
							fontSize: 64,
							fontWeight: 'bold',
							background: 'linear-gradient(135deg, #9333ea 0%, #3b82f6 100%)',
							WebkitBackgroundClip: 'text',
							WebkitTextFillColor: 'transparent',
							marginBottom: 20,
						}}
					>
						Try it now
					</div>
					<div
						style={{
							fontSize: 36,
							color: '#9ca3af',
						}}
					>
						Install in 30 seconds
					</div>
				</div>

				{/* Installation command */}
				<div
					style={{
						opacity: ctaOpacity,
						marginTop: 60,
						backgroundColor: '#1e1e1e',
						padding: '30px 50px',
						borderRadius: 12,
						display: 'inline-block',
					}}
				>
					<div
						style={{
							fontFamily: 'monospace',
							fontSize: 28,
							color: '#10b981',
						}}
					>
						$ ./feature-marker/install.sh
					</div>
				</div>
			</div>
		</AbsoluteFill>
	);
};
