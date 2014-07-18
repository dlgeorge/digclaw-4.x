c
c
c =========================================================
      subroutine src2(maxmx,maxmy,meqn,mbc,mx,my,xlower,ylower,dx,dy,
     &             q,maux,aux,t,dt)
c =========================================================
      use geoclaw_module
      use digclaw_module

      implicit none

      !i/o
      double precision q(1-mbc:maxmx+mbc,1-mbc:maxmy+mbc, meqn)
      double precision aux(1-mbc:maxmx+mbc,1-mbc:maxmy+mbc, maux)
      double precision xlower,ylower,dx,dy,t,dt
      integer maxmx,maxmy,meqn,mbc,mx,my,maux

      !local
      double precision gmod,h,hu,hv,hm,u,v,m,p,phi,kappa,S,rho,tanpsi
      double precision D,tau,sigbed,kperm,compress,pm,coeff,tol
      double precision zeta,p_hydro,p_litho,p_eq,krate,gamma,dgamma
      double precision cx,cy,pdh,vnorm,hvnorm,theta,dtheta,D2x,D2y
      integer i,j,ii,jj,icount
c

c     # check for NANs in solution:
      call check4nans(maxmx,maxmy,meqn,mbc,mx,my,q,t,2)


      pm=1.d0

      gmod=grav
      coeff = coeffmanning
      tol = 1.d-30  !# to prevent divide by zero in gamma
      !write(*,*) 'src:init,value',p_initialized,init_pmin_ratio

      do i=1,mx
         do j=1,my
            theta = 0.d0
            dtheta = 0.d0
            if (bed_normal.eq.1) then
               theta = aux(i,j,i_theta)
               gmod = grav*dcos(theta)
               dtheta = -(aux(i+1,j,i_theta) - theta)/dx
            endif
            call admissibleq(q(i,j,1),q(i,j,2),q(i,j,3),
     &            q(i,j,4),q(i,j,5),u,v,m,theta)
            h = q(i,j,1)
            if (h.le.drytolerance) cycle
            hu = q(i,j,2)
            hv = q(i,j,3)
            hm = q(i,j,4)
            p =  q(i,j,5)
            phi = aux(i,j,i_phi)

            !integrate momentum source term
            call auxeval(h,u,v,m,p,phi,theta,kappa,S,rho,tanpsi,D,tau,
     &                  sigbed,kperm,compress,pm)



            vnorm = dsqrt(u**2 + v**2)
            hvnorm = h*vnorm

            !if (dtheta.gt.0.d0) then
            !   tau = tau*(gmod + dtheta*vnorm**2)/gmod
            !endif

            if (vnorm.gt.0.d0) then
               !hvnorm = dmax1(0.d0,hvnorm - dt*tau/rho)
               hvnorm = hvnorm*dexp(-(1.d0-m)*2.0*mu*dt/(rho*h**2))
               if (hvnorm<1.e-6) hvnorm = 0.0
               hu = hvnorm*u/vnorm
               hv = hvnorm*v/vnorm
            endif

            if (p_initialized.eq.0) cycle

            call admissibleq(h,hu,hv,hm,p,u,v,m,theta)
            call auxeval(h,u,v,m,p,phi,theta,kappa,S,rho,tanpsi,D,tau,
     &                  sigbed,kperm,compress,pm)


            vnorm = dsqrt(u**2 + v**2)

            !integrate shear-induced dilatancy
c            p = p - dt*3.0*vnorm*tanpsi/(h*compress)

            !integrate pressure relaxation
            zeta = 3.d0/(compress*h*2.0)  +
     &        (rho-rho_f)*rho_f*gmod/(4.d0*rho)

            krate=-zeta*2.0*kperm/(h*dmax1(mu,1.d-16))
            p_hydro = h*rho_f*gmod
            p_litho = (rho_s*m + (1.d0-m)*rho_f)*gmod*h

            p_eq = p_hydro + 3.0*vnorm*tanpsi/(compress*h*krate)
            !p_eq = max(p_eq,0.0)
            !p_eq = min(p_eq,p_litho)
            p = p_eq + (p-p_eq)*dexp(krate*dt)

            call admissibleq(h,hu,hv,hm,p,u,v,m,theta)
            call auxeval(h,u,v,m,p,phi,theta,kappa,S,rho,tanpsi,D,tau,
     &                  sigbed,kperm,compress,pm)

            krate = D*(rho-rho_f)/rho
            hu = hu*dexp(dt*krate/h)
            hv = hv*dexp(dt*krate/h)
            hm = hm*dexp(-dt*D*rho_f/(h*rho))
            h = h + krate*dt

            call admissibleq(h,hu,hv,hm,p,u,v,m,theta)
c            !vnorm = dsqrt(u**2 + v**2)
            call auxeval(h,u,v,m,p,phi,theta,kappa,S,rho,tanpsi,D,tau,
     &                  sigbed,kperm,compress,pm)

            q(i,j,1) = h
            q(i,j,2) = hu
            q(i,j,3) = hv
            q(i,j,4) = hm
            q(i,j,5) = p

         enddo
      enddo

      !diffusion?
      if (.false.) then
      do i=1,mx
         do j=1,my
         if (q(i,j,1).le.drytolerance) cycle
            p = 0.0
            icount = 0
            do ii=-1,1
               do jj=-1,1
                  if (q(i+ii,j+jj,1).gt.drytolerance) then
                     p = p + q(i+ii,j+jj,5)/q(i+ii,j+jj,1)
                     icount = icount + 1
                  endif
               enddo
            enddo
            aux(i,j,8) = p/icount
         enddo
      enddo
      do i=1,mx
         do j=1,my
            if (q(i,j,1).le.drytolerance) cycle
            q(i,j,5) = aux(i,j,8)*q(i,j,1)
         enddo
      enddo
      endif

*     ! Manning friction------------------------------------------------
      if (coeffmanning.gt.0.d0.and.frictiondepth.gt.0.d0) then
         do i=1,mx
            do j=1,my
               if (bed_normal.eq.1) gmod = grav*dcos(aux(i,j,i_theta))
               h=q(i,j,1)
               if (h.le.frictiondepth) then
c                 # apply friction source term only in shallower water
                  hu=q(i,j,2)
                  hv=q(i,j,3)

                  if (h.lt.tol) then
                     q(i,j,2)=0.d0
                     q(i,j,3)=0.d0
                  else
                     gamma= dsqrt(hu**2 + hv**2)*
     &                  (gmod*coeff**2)/(h**(7.0/3.0))
                     dgamma=1.d0 + dt*gamma
                     q(i,j,2)= q(i,j,2)/dgamma
                     q(i,j,3)= q(i,j,3)/dgamma
                  endif
               endif
            enddo
         enddo
      endif
*     ! ----------------------------------------------------------------


c
      return
      end
