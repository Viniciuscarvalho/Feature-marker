import {AbsoluteFill, Sequence} from 'remotion';
import {IntroScene} from './IntroScene';
import {BasicCommandScene} from './BasicCommandScene';
import {InteractivePanelScene} from './InteractivePanelScene';
import {WorkflowScene} from './WorkflowScene';
import {OutroScene} from './OutroScene';

export const MainVideo: React.FC = () => {
	return (
		<AbsoluteFill style={{backgroundColor: '#0a0a0a'}}>
			{/* Scene 1: Intro (0-10s) */}
			<Sequence from={0} durationInFrames={300}>
				<IntroScene />
			</Sequence>

			{/* Scene 2: Basic Command (10-20s) */}
			<Sequence from={300} durationInFrames={300}>
				<BasicCommandScene />
			</Sequence>

			{/* Scene 3: Interactive Panel (20-40s) */}
			<Sequence from={600} durationInFrames={600}>
				<InteractivePanelScene />
			</Sequence>

			{/* Scene 4: Workflow Execution (40-50s) */}
			<Sequence from={1200} durationInFrames={300}>
				<WorkflowScene />
			</Sequence>

			{/* Scene 5: Outro (50-60s) */}
			<Sequence from={1500} durationInFrames={300}>
				<OutroScene />
			</Sequence>
		</AbsoluteFill>
	);
};
