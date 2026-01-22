import {AbsoluteFill, useCurrentFrame, interpolate} from 'remotion';

export const BasicCommandScene: React.FC = () => {
	const frame = useCurrentFrame();

	// Terminal fade in
	const terminalOpacity = interpolate(frame, [0, 20], [0, 1], {
		extrapolateRight: 'clamp',
	});

	// Command typing effect
	const command = '/feature-marker prd-user-authentication';
	const typedLength = Math.floor(interpolate(frame, [30, 90], [0, command.length], {
		extrapolateRight: 'clamp',
	}));
	const typedCommand = command.substring(0, typedLength);

	// Workflow diagram fade in
	const workflowOpacity = interpolate(frame, [120, 150], [0, 1], {
		extrapolateRight: 'clamp',
	});

	// Workflow items appear sequentially
	const phase1Opacity = interpolate(frame, [160, 180], [0, 1], {extrapolateRight: 'clamp'});
	const phase2Opacity = interpolate(frame, [180, 200], [0, 1], {extrapolateRight: 'clamp'});
	const phase3Opacity = interpolate(frame, [200, 220], [0, 1], {extrapolateRight: 'clamp'});
	const phase4Opacity = interpolate(frame, [220, 240], [0, 1], {extrapolateRight: 'clamp'});

	return (
		<AbsoluteFill
			style={{
				backgroundColor: '#0a0a0a',
				justifyContent: 'center',
				alignItems: 'center',
				padding: 60,
			}}
		>
			{/* Terminal */}
			<div
				style={{
					opacity: terminalOpacity,
					backgroundColor: '#1e1e1e',
					borderRadius: 12,
					padding: 40,
					width: '80%',
					maxWidth: 1200,
					boxShadow: '0 20px 60px rgba(0, 0, 0, 0.5)',
				}}
			>
				{/* Terminal header */}
				<div style={{display: 'flex', gap: 8, marginBottom: 30}}>
					<div style={{width: 12, height: 12, borderRadius: '50%', backgroundColor: '#ff5f56'}} />
					<div style={{width: 12, height: 12, borderRadius: '50%', backgroundColor: '#ffbd2e'}} />
					<div style={{width: 12, height: 12, borderRadius: '50%', backgroundColor: '#27c93f'}} />
				</div>

				{/* Command */}
				<div
					style={{
						fontFamily: 'monospace',
						fontSize: 36,
						color: '#9333ea',
					}}
				>
					{typedCommand}
					{frame < 90 && <span style={{animation: 'blink 1s infinite'}}>|</span>}
				</div>
			</div>

			{/* Workflow diagram */}
			<div
				style={{
					position: 'absolute',
					bottom: 100,
					opacity: workflowOpacity,
					display: 'flex',
					gap: 40,
					alignItems: 'center',
				}}
			>
				<WorkflowPhase emoji="🚦" label="Inputs Gate" opacity={phase1Opacity} />
				<Arrow opacity={phase1Opacity} />
				<WorkflowPhase emoji="📋" label="Analysis" opacity={phase2Opacity} />
				<Arrow opacity={phase2Opacity} />
				<WorkflowPhase emoji="⚡" label="Implementation" opacity={phase3Opacity} />
				<Arrow opacity={phase3Opacity} />
				<WorkflowPhase emoji="🚀" label="Commit & PR" opacity={phase4Opacity} />
			</div>
		</AbsoluteFill>
	);
};

const WorkflowPhase: React.FC<{emoji: string; label: string; opacity: number}> = ({
	emoji,
	label,
	opacity,
}) => (
	<div
		style={{
			opacity,
			textAlign: 'center',
		}}
	>
		<div style={{fontSize: 48, marginBottom: 10}}>{emoji}</div>
		<div style={{fontSize: 20, color: '#ffffff', fontWeight: 600}}>{label}</div>
	</div>
);

const Arrow: React.FC<{opacity: number}> = ({opacity}) => (
	<div
		style={{
			opacity,
			fontSize: 40,
			color: '#3b82f6',
		}}
	>
		→
	</div>
);
