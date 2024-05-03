@Library('gyroidos_ci_common') _

pipeline {
	agent any

	options {
		copyArtifactPermission('/GyroidOS_Pipelines/**');
	}

	environment {
		YOCTO_VERSION = 'kirkstone'
		BUILDUSER = "${sh(script:'id -u', returnStdout: true).trim()}"
		KVM_GID = "${sh(script:'getent group kvm | cut -d: -f3', returnStdout: true).trim()}"
	}

	parameters {
		choice(name: 'GYROID_ARCH', choices: ['x86', 'arm32', 'arm64'], description: 'GyroidOS Target Architecture')
		choice(name: 'GYROID_MACHINE', choices: ['genericx86-64', 'apalis-imx8', 'raspberrypi3-64', 'raspberrypi2', 'tqma8mpxl'], description: 'GyroidOS Target Machine (Must be compatible with GYROID_ARCH!)')
		string(name: 'PR_BRANCHES', defaultValue: '', description: 'Comma separated list of pull request branches (e.g. meta-trustx=PR-177,meta-trustx-nxp=PR-13,gyroidos_build=PR-97)')
		choice(name: 'BUILD_INSTALLER', choices: ['n', 'y'], description: 'Build the GyroidOS installer (x86 only)')
		choice(name: 'REBUILD_PREVIOUS', choices: ['n', 'y'], description: 'Rebuild selected, previous build instead of just reusing image from artifacts')
		buildSelector defaultSelector: specific('${BUILD_NUMBER}'), name: 'BUILDSELECTOR', description: 'Image to perform integration tests on. Changing the default value skips the image build.'
		choice(name: 'SYNC_MIRRORS', choices: ['n', 'y'], description: 'Sync source mirrors after successful build')
	}


	stages {
		stage('Source checks + unit tests') {
			agent {
					dockerfile {
						dir '.'
						additionalBuildArgs '--build-arg=BUILDUSER=$BUILDUSER'
						args '--entrypoint=\'\' --env NODE_NAME="${NODE_NAME}" -v /yocto_mirror/${YOCTO_VERSION}/${GYROID_ARCH}/sources:/source_mirror -v /yocto_mirror/${YOCTO_VERSION}/${GYROID_ARCH}/sstate-cache:/sstate_mirror'
						reuseNode true
					}
			}

			stages {
				stage ('Prepare workspace') {
					steps {
						echo "Running on node $NODE_NAME"

						stepInitWs(manifest: "testmanifest.xml", workspace: "${WORKSPACE}", manifest_path: "${WORKSPACE}/.manifests", manifest_name: "yocto-${GYROID_ARCH}-${GYROID_MACHINE}.xml", gyroid_arch: GYROID_ARCH, gyroid_machine: GYROID_MACHINE, selector: buildParameter('BUILDSELECTOR'), rebuild_previous: "${REBUILD_PREVIOUS}", buildtype: "dev", pr_branches: PR_BRANCHES)
					}
				}

				stage ('Source Tests') {
					when { expression { return false }}
		//			when {
		//				expression {
		//					if (! fileExists("trustme/cml")) {
		//						echo "CML sources not available, skipping initial tests"
		//						return false
		//					} else {
		//						echo "CML sources available, performing initial tests"
		//						return true
		//					}
		//				}
		//			}

					parallel {
							stage ('Code Format & Style') {
								steps {
									echo "Entering format test stage, workspace: ${WORKSPACE}"
									stepFormatCheck(workspace: WORKSPACE, sourcedir: "${WORKSPACE}/trustme/cml")
								}
							}

							/*
							 Intentionally mark the static code analysis stage as skipped
							 We want to show that we are performing static code analysis, but not
							 as part of Jenkins's pipeline.
							*/
							stage('Static Code Analysis') {
								when { expression { return false }}

								steps {
									sh label: 'Perform static code analysis', script: '''
										echo "Static Code Analysis is performed using Semmle."
										echo "Please check GitHub's project for results from Semmle's analysis."
									'''
								}
							}

							stage ('Unit tests') {
								steps {
									script {
										echo "Running on node $NODE_NAME"
										stepUnitTests(workspace: WORKSPACE, sourcedir: "${WORKSPACE}/trustme/cml")
									}
								}


							}
						}
					}
				}
			} // Source checks + unit tests


		stage ('Build + Test Images') {

			// Build images in parallel
			matrix {
				axes {
					axis {
						name 'BUILDTYPE'
						values 'dev', 'production', 'ccmode', 'schsm'
					}
				}

				agent {
					dockerfile {
						dir "."
						additionalBuildArgs '--build-arg=BUILDUSER=$BUILDUSER'
						args '--entrypoint=\'\' -v /yocto_mirror/${YOCTO_VERSION}/${GYROID_ARCH}/sources:/source_mirror -v /yocto_mirror/${YOCTO_VERSION}/${GYROID_ARCH}/sstate-cache:/sstate_mirror --env NODE_NAME="${NODE_NAME}" -v /home/jenkins-ssh/.ssh/known_hosts:/home/builder/.ssh/known_hosts'
						reuseNode false
					}
				}

				stages {
					stage ('Build image') {
						//when { expression { return false }}
						steps {
							script {
								if ("y" == "${SYNC_MIRRORS}") {
									sshagent(credentials: ['MIRROR_ACCESS']){
										sh "ssh jenkins-ssh@${env.MIRRORHOST} \"ls -al /yocto_mirror\""


										stepBuildImage(workspace: WORKSPACE, manifest_path: "${WORKSPACE}/.manifests", manifest_name: "yocto-${GYROID_ARCH}-${GYROID_MACHINE}.xml", yocto_version: YOCTO_VERSION, gyroid_arch: GYROID_ARCH, gyroid_machine: GYROID_MACHINE, buildtype: BUILDTYPE, selector: buildParameter('BUILDSELECTOR'), build_installer: BUILD_INSTALLER, sync_mirrors: SYNC_MIRRORS, rebuild_previous: REBUILD_PREVIOUS)
									}
								} else {
									echo "wont sync mirrors"

									stepBuildImage(workspace: WORKSPACE, manifest_path: "${WORKSPACE}/.manifests", manifest_name: "yocto-${GYROID_ARCH}-${GYROID_MACHINE}.xml", yocto_version: YOCTO_VERSION, gyroid_arch: GYROID_ARCH, gyroid_machine: GYROID_MACHINE, buildtype: BUILDTYPE, selector: buildParameter('BUILDSELECTOR'), build_installer: BUILD_INSTALLER, sync_mirrors: SYNC_MIRRORS, rebuild_previous: REBUILD_PREVIOUS)
								}
							}
						}
					}
				}
			} // matrix
		} // stage 'Build + Test Images'


		stage ('Integration Tests') {
			matrix {
				axes {
					axis {
						name 'BUILDTYPE'
						values 'dev', 'production', 'ccmode'
					}
				}

				agent {
					dockerfile {
						dir "."
						additionalBuildArgs '--build-arg=BUILDUSER=$BUILDUSER'
						args '--entrypoint=\'\' -v /yocto_mirror:/yocto_mirror --device=/dev/kvm --group-add=$KVM_GID -p 2222 -p 5901 --env NODE_NAME="${NODE_NAME}"'
						label 'worker'
					}
				}

				stages {
					stage ('Perform tests') {
						steps {
							stepIntegrationTest(workspace: "${WORKSPACE}", gyroid_arch: GYROID_ARCH, gyroid_machine: GYROID_MACHINE, buildtype: "${BUILDTYPE}", selector: buildParameter('BUILDSELECTOR'), schsm_serial: "", schsm_pin: "")
						}
					} // stage 'Perform tests'
				} // stages
			} // matrix
		} // stage 'Integration Tests'

		stage ('Token Tests') {
			agent {
				node { label 'testing' }
			}

			steps {
				stepIntegrationTest(workspace: "${WORKSPACE}", gyroid_arch: GYROID_ARCH, gyroid_machine: GYROID_MACHINE, buildtype: "schsm", selector: buildParameter('BUILDSELECTOR'), schsm_serial: "${env.PHYSHSM}", schsm_pin: "12345678")
			}
		} // stage 'Token Tests'


		/*TODO deploy the development and production images on separate machines
		  and start demo applications inside them (e.g. a webserver)*/
		stage('Live Deployment') {
			parallel {
				stage('Development Image') {
					/*TODO;Skipped for now*/
					when {
						expression {
							/*If branch trustx master and comes from main repo?*/
							return false
						}
					}

					steps {
						sh 'echo pass'
					}
				}

				stage('Production Image') {
					/*TODO;Skipped for now*/
					when {
						expression {
							/*If branch trustx master and comes from main repo?*/
							return false
						}
					}
					steps {
						sh 'echo pass'
					}
				}
			}
		}


		stage('Documentation Generation') {
			/*TODO;Skipped for now*/
			when {
				expression {
					/*If branch trustx master and comes from main repo?*/
					return false
				}
			}

			steps {
				sh 'echo pass'
			}
		} // stage 'Documentation Generation'
	} // stages
} // pipeline
