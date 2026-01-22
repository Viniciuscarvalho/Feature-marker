import {AbsoluteFill, useCurrentFrame, interpolate, spring, useVideoConfig} from 'remotion';

export const WorkflowScene: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();

	return (
		<AbsoluteFill
			style={{
				backgroundColor: '#0a0a0a',
				justifyContent: 'center',
				alignItems: 'center',
				padding: 80,
			}}
		>
			<div style={{width: '100%', maxWidth: 1000}}>
				<div
					style={{
						fontSize: 48,
						fontWeight: 'bold',
						color: '#ffffff',
						marginBottom: 60,
						textAlign: 'center',
					}}
				>
					Workflow Execution
				</div>

				<div style={{display: 'flex', flexDirection: 'column', gap: 40}}>
					<PhaseProgress
						number={1}
						name="Analysis & Planning"
						emoji="📋"
						frame={frame}
						startFrame={20}
						fps={fps}
					/>
					<PhaseProgress
						number={2}
						name="Implementation"
						emoji="⚡"
						frame={frame}
						startFrame={90}
						fps={fps}
					/>
					<PhaseProgress
						number={3}
						name="Tests & Validation"
						emoji="🧪"
						frame={frame}
						startFrame={160}
						fps={fps}
					/>
					<PhaseProgress
						number={4}
						name="Commit & PR"
						emoji="🚀"
						frame={frame}
						startFrame={230}
						fps={fps}
					/>
				</div>
			</div>
		</AbsoluteFill>
	);
};

const PhaseProgress: React.FC<{
	number: number;
	name: string;
	emoji: string;
	frame: number;
	startFrame: number;
	fps: number;
}> = ({number, name, emoji, frame, startFrame, fps}) => {
	const progress = interpolate(
		frame,
		[startFrame, startFrame + 50],
		[0, 100],
		{
			extrapolateRight: 'clamp',
			extrapolateLeft: 'clamp',
		}
	);

	const isComplete = frame >= startFrame + 50;

	const checkmarkScale = spring({
		frame: Math.max(0, frame - (startFrame + 50)),
		fps,
		config: {
			damping: 200,
		},
	});

	const checkmarkOpacity = frame >= startFrame + 50 ? 1 : 0;

	return (
		<div>
			<div
				style={{
					display: 'flex',
					justifyContent: 'space-between',
					alignItems: 'center',
					marginBottom: 15,
				}}
			>
				<div style={{display: 'flex', alignItems: 'center', gap: 15}}>
					<span style={{fontSize: 36}}>{emoji}</span>
					<span style={{fontSize: 28, color: '#ffffff', fontWeight: 600}}>
						Phase {number}: {name}
					</span>
				</div>
				<div
					style={{
						opacity: checkmarkOpacity,
						transform: `scale(${checkmarkScale})`,
						color: '#10b981',
						fontSize: 36,
						fontWeight: 'bold',
					}}
				>
					✓
				</div>
			</div>

			{/* Progress bar */}
			<div
				style={{
					width: '100%',
					height: 12,
					backgroundColor: '#374151',
					borderRadius: 6,
					overflow: 'hidden',
				}}
			>
				<div
					style={{
						width: `${progress}%`,
						height: '100%',
						background: isComplete
							? 'linear-gradient(90deg, #10b981 0%, #059669 100%)'
							: 'linear-gradient(90deg, #9333ea 0%, #3b82f6 100%)',
						transition: 'width 0.1s linear',
					}}
				/>
			</div>
		</div>
	);
};
