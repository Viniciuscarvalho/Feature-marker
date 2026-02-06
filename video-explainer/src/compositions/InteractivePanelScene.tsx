import {AbsoluteFill, useCurrentFrame, interpolate} from 'remotion';

export const InteractivePanelScene: React.FC = () => {
	const frame = useCurrentFrame();

	// Panel slide in from left
	const panelX = interpolate(frame, [0, 40], [-1000, 0], {
		extrapolateRight: 'clamp',
	});

	// Options highlight sequentially
	const option1Highlight = frame >= 80 && frame < 160;
	const option2Highlight = frame >= 160 && frame < 240;
	const option3Highlight = frame >= 240 && frame < 320;
	const option4Highlight = frame >= 320;

	// Descriptions fade in
	const desc1Opacity = interpolate(frame, [100, 120], [0, 1], {extrapolateRight: 'clamp'});
	const desc2Opacity = interpolate(frame, [180, 200], [0, 1], {extrapolateRight: 'clamp'});
	const desc3Opacity = interpolate(frame, [260, 280], [0, 1], {extrapolateRight: 'clamp'});
	const desc4Opacity = interpolate(frame, [340, 360], [0, 1], {extrapolateRight: 'clamp'});

	return (
		<AbsoluteFill
			style={{
				backgroundColor: '#0a0a0a',
				justifyContent: 'center',
				alignItems: 'center',
			}}
		>
			{/* Interactive Panel */}
			<div
				style={{
					transform: `translateX(${panelX}px)`,
					backgroundColor: '#1e1e1e',
					borderRadius: 16,
					padding: 45,
					boxShadow: '0 25px 70px rgba(147, 51, 234, 0.3)',
					border: '2px solid #9333ea',
					minWidth: 850,
				}}
			>
				{/* Header */}
				<div
					style={{
						fontSize: 36,
						fontWeight: 'bold',
						color: '#ffffff',
						marginBottom: 30,
						textAlign: 'center',
						borderBottom: '2px solid #374151',
						paddingBottom: 18,
					}}
				>
					🚀 Feature Marker - Execution Mode
				</div>

				{/* Options */}
				<div style={{display: 'flex', flexDirection: 'column', gap: 18}}>
					<MenuOption
						number="1"
						title="Full Workflow"
						subtitle="Generate PRD/TechSpec/Tasks + Implementation"
						description="Creates missing files and executes all phases"
						isHighlighted={option1Highlight}
						descriptionOpacity={desc1Opacity}
					/>

					<MenuOption
						number="2"
						title="Tasks Only"
						subtitle="Skip generation, run implementation"
						description="Use existing PRD/TechSpec/Tasks (must exist)"
						isHighlighted={option2Highlight}
						descriptionOpacity={desc2Opacity}
					/>

					<MenuOption
						number="3"
						title="Ralph Loop Mode"
						subtitle="Autonomous loop execution"
						description="Uses ralph-wiggum for continuous iteration"
						isHighlighted={option3Highlight}
						descriptionOpacity={desc3Opacity}
					/>

					<MenuOption
						number="4"
						title="Spec-Driven Mode"
						subtitle="Multi-agent review + worktree isolation"
						description="Uses spec-workflow for rigorous spec review"
						isHighlighted={option4Highlight}
						descriptionOpacity={desc4Opacity}
						isNew
					/>
				</div>
			</div>
		</AbsoluteFill>
	);
};

const MenuOption: React.FC<{
	number: string;
	title: string;
	subtitle: string;
	description: string;
	isHighlighted: boolean;
	descriptionOpacity: number;
	isNew?: boolean;
}> = ({number, title, subtitle, description, isHighlighted, descriptionOpacity, isNew}) => (
	<div
		style={{
			backgroundColor: isHighlighted ? 'rgba(147, 51, 234, 0.2)' : 'transparent',
			border: isHighlighted ? '2px solid #9333ea' : '2px solid transparent',
			borderRadius: 12,
			padding: 16,
		}}
	>
		<div style={{display: 'flex', alignItems: 'flex-start', gap: 18}}>
			<div
				style={{
					fontSize: 28,
					fontWeight: 'bold',
					color: isHighlighted ? '#9333ea' : '#6b7280',
				}}
			>
				{number})
			</div>
			<div style={{flex: 1}}>
				<div style={{display: 'flex', alignItems: 'center', gap: 12}}>
					<div
						style={{
							fontSize: 24,
							fontWeight: 'bold',
							color: '#ffffff',
						}}
					>
						{title}
					</div>
					{isNew && (
						<div
							style={{
								backgroundColor: '#10b981',
								color: '#ffffff',
								fontSize: 12,
								fontWeight: 'bold',
								padding: '4px 10px',
								borderRadius: 20,
							}}
						>
							NEW v2.0
						</div>
					)}
				</div>
				<div
					style={{
						fontSize: 18,
						color: '#9ca3af',
						marginBottom: 6,
						marginTop: 3,
					}}
				>
					{subtitle}
				</div>
				<div
					style={{
						fontSize: 16,
						color: '#6b7280',
						opacity: descriptionOpacity,
						fontStyle: 'italic',
					}}
				>
					→ {description}
				</div>
			</div>
		</div>
	</div>
);
